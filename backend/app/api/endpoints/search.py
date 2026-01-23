from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.api_schemas import SearchRequest, BodegaSearchResult, ProductItem, SmartSearchResponse
from app.services.gemini_service import gemini_client
from app.repositories.inventory_repo import InventoryRepository
import json
import unicodedata

router = APIRouter()

# --- UTILITARIOS ---

def normalize_text(text: str) -> str:
    """Elimina tildes y pasa a minúsculas."""
    if not text: return ""
    return ''.join(
        c for c in unicodedata.normalize('NFD', text.lower())
        if unicodedata.category(c) != 'Mn'
    )

def humanize_attributes(attrs: dict) -> str:
    """Convierte atributos a texto natural (con gas, sin gas, etc)."""
    if not attrs: return ""
    text_parts = []
    for k, v in attrs.items():
        key_norm = normalize_text(k)
        val_norm = normalize_text(str(v))
        text_parts.append(key_norm) 
        text_parts.append(val_norm) 
        
        if isinstance(v, bool):
            if v is True:
                text_parts.extend([f"con {key_norm}", "si"])
            else:
                text_parts.extend([f"sin {key_norm}", "no"])
                
    return " ".join(text_parts)

def normalize_capacity(text: str) -> str:
    """
    Normaliza capacidades a mililitros para comparación uniforme.
    Ejemplos: "2L" -> "2000ml", "2 litros" -> "2000ml", "1.5L" -> "1500ml"
    """
    import re
    if not text: return ""
    
    text_lower = text.lower().strip()
    normalized_variants = []
    
    # Buscar patrones de litros: 2L, 2 litros, 2.5L, etc
    litros_patterns = [
        r'(\d+\.?\d*)\s*l(?:itros?)?(?:\s|$)',  # 2L, 2 litros, 2.5L
        r'(\d+\.?\d*)\s*lts?(?:\s|$)',           # 2 lts
    ]
    
    for pattern in litros_patterns:
        matches = re.findall(pattern, text_lower)
        for match in matches:
            ml_value = int(float(match) * 1000)
            normalized_variants.append(f"{ml_value}ml")
    
    # Buscar patrones de mililitros: 500ml, 500 ml, etc
    ml_patterns = [
        r'(\d+)\s*ml(?:\s|$)',
        r'(\d+)\s*mililitros?(?:\s|$)',
    ]
    
    for pattern in ml_patterns:
        matches = re.findall(pattern, text_lower)
        for match in matches:
            normalized_variants.append(f"{match}ml")
    
    # Agregar el texto original normalizado también
    normalized_variants.append(normalize_text(text))
    
    return " ".join(normalized_variants)

# -------------------

from app.models.tables import ChatSession, ChatMessage
from sqlalchemy import desc, func

@router.post("/smart", response_model=SmartSearchResponse)
async def search_smart(request: SearchRequest, db: Session = Depends(get_db)):
    
    print(f"\n📍 [DEBUG] Ubicación: {request.user_lat}, {request.user_lon}")

    # --- 1. GESTIÓN DE MEMORIA (HISTORIAL EN BD) ---
    history_for_gemini = request.conversation_history # Fallback por defecto
    current_session = None

    if request.user_id:
        print(f"👤 [API] ID DE USUARIO RECIBIDO: {request.user_id}")
        
        # A. ESTRATEGIA DE SESIÓN (STRICT MODE)
        
        # 1. Prioridad Máxima: Session ID explícito desde Frontend
        if request.session_id:
            current_session = db.query(ChatSession).filter(ChatSession.id == request.session_id).first()
            if current_session:
                 print(f"✅ [DB-MEM] Sesión explícita encontrada: {current_session.id}")
                 # Asegurar flag active
                 if not current_session.is_active:
                     current_session.is_active = True
                     # Desactivar otras para mantener orden
                     db.query(ChatSession).filter(
                         ChatSession.user_id == request.user_id, 
                         ChatSession.id != current_session.id
                     ).update({"is_active": False})
                     db.commit()

        # 2. Fallback: ELIMINADO. Si no hay ID explícito, queremos NUEVA sesión siempre.
        # if not current_session:
        #    current_session = db.query(ChatSession).filter(...).first()

        # 3. Último recurso: Crear NUEVA (Nunca reactivar viejas al azar)
        if not current_session:
            print("🆕 [DB-MEM] Creando nueva sesión limpia (Sin mezclar historial)")
            current_session = ChatSession(user_id=request.user_id, is_active=True)
            db.add(current_session)
            db.commit()
            db.refresh(current_session)
            
            # Desactivar otras anteriores por seguridad
            db.query(ChatSession).filter(
                 ChatSession.user_id == request.user_id, 
                 ChatSession.id != current_session.id
            ).update({"is_active": False})
            db.commit()

        
        # B. Guardar mensaje del Usuario
        user_msg = ChatMessage(
            session_id=current_session.id,
            role="user",
            content=request.query
        )
        db.add(user_msg)
        
        # Actualizar timestamp de la sesión
        current_session.updated_at = func.now()
        db.commit() # Commit inicial para asegurar que el mensaje está guardado

        # C. Recuperar estado de búsqueda persistente
        search_state = current_session.search_state or []
    else:
        search_state = []

    # --- 2. CLASIFICACIÓN DE INTENCIÓN ---
    intent_data = await gemini_client.classify_intent(request.query)
    intent_type = intent_data.get("intent", "UNKNOWN")
    requires_search = intent_data.get("requires_search", True)
    requires_state = intent_data.get("requires_state", False)
    clear_state = intent_data.get("clear_state", False)
    
    is_inappropriate = intent_data.get("is_inappropriate", False)
    
    print(f"🎯 [INTENT] Tipo: {intent_type}, Buscar: {requires_search}, Estado: {requires_state}, Limpiar: {clear_state}, Inapropiado: {is_inappropriate}")
    
    # --- 3. MANEJO SEGÚN TIPO DE INTENCIÓN ---
    
    # CASO 0: Contenido inapropiado - Rechazar sin llamar a Gemini (ahorra API)
    if intent_type == "INAPPROPRIATE" or is_inappropriate:
        # Mensaje fijo para no gastar API
        bot_message = "Aea CHOLA, mejor escucha El Gran Cagón 😹😹"
        
        # Guardar advertencia pero NO respuesta elaborada
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
        
        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None
        )
    
    # CASO A: Saludos y Despedidas - Solo responder, NO buscar productos
    if intent_type in ["GREETING", "FAREWELL"]:
        bot_message = await gemini_client.generate_conversational_response(request.query, intent_type)
        
        # Guardar respuesta del bot
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
        
        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None
        )
    
    # CASO B: Limpiar carrito
    if intent_type == "CLEAR_CART" or clear_state:
        if current_session:
            current_session.search_state = []
            db.commit()
        
        bot_message = await gemini_client.generate_conversational_response(request.query, "CLEAR_CART")
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
        
        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None
        )
    
    # CASO C: Recordar pedido anterior - Solo mostrar el estado guardado
    if intent_type == "RECALL_PREVIOUS":
        if search_state:
            products_str = ", ".join([f"{p.get('quantity', 1)}x {p.get('product_name', 'producto')}" for p in search_state])
            context = f"Pedido guardado: {products_str}"
        else:
            context = "No hay pedido guardado"
        
        bot_message = await gemini_client.generate_conversational_response(request.query, "RECALL_PREVIOUS", context)
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
        
        # Si hay estado, hacer búsqueda con esos productos
        if search_state:
            # Continuar con la búsqueda usando el estado guardado
            intent_items = search_state
        else:
            return SmartSearchResponse(
                message=bot_message, 
                results=[],
                session_id=current_session.id if current_session else None
            )
    
    # CASO D: Confirmación simple
    elif intent_type == "CONFIRMATION":
        if search_state:
            # Continuar con el pedido actual
            intent_items = search_state
            context = f"Confirmando pedido con {len(search_state)} productos"
        else:
            bot_message = await gemini_client.generate_conversational_response(request.query, "CONFIRMATION", "No hay pedido pendiente")
            
            if current_session:
                bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
                db.add(bot_msg_db)
                db.commit()
            
            return SmartSearchResponse(
                message=bot_message, 
                results=[],
                session_id=current_session.id if current_session else None
            )
    
    # CASO E: Búsqueda, Agregar, Modificar, Pregunta - Requieren procesamiento
    else:
        # Determinar si usamos el estado anterior
        state_to_use = search_state if requires_state else []
        
        # Llamar a interpret_search_intent con el tipo de intención
        updated_state = await gemini_client.interpret_search_intent(
            request.query, 
            state_to_use, 
            intent_type
        )
        intent_items = updated_state
        
        # Persistir el nuevo estado si hay sesión (pero NO para QUESTION)
        if current_session and intent_type != "QUESTION":
            current_session.search_state = updated_state
            db.commit()
        
        print(f"🤖 [DEBUG] Estado anterior: {search_state}")
        print(f"🤖 [DEBUG] Nuevo estado: {updated_state}")

    # --- 4. VERIFICAR SI HAY PRODUCTOS PARA BUSCAR ---
    keywords = [item.get("product_name", "") for item in intent_items]
    keywords = [k for k in keywords if k]  # Filtrar vacíos
    print(f"🤖 [DEBUG] Keywords para buscar: {keywords}")

    if not keywords:
        # No hay productos que buscar - responder de forma conversacional
        msg = await gemini_client.generate_shopkeeper_response(request.query, "Sin intención clara de producto.")
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=msg)
            db.add(bot_msg_db)
            db.commit()
        
        return SmartSearchResponse(message=msg, results=[])

    # 2. Buscar en BD
    raw_results = InventoryRepository.search_products_smart(
        db, keywords, request.user_lat, request.user_lon
    )

    # 3. SISTEMA DE SCORING INTELIGENTE + ASIGNACIÓN DE CANTIDAD
    # Estructura: scored_results = [(inv, prod, bodega, qty, score, intent_index)]
    scored_results = []
    
    print(f"🔍 [SEARCH] Raw DB Results: {len(raw_results)}")
    
    for inv, prod, bodega in raw_results:
        # Normalizamos textos del producto
        prod_name_norm = normalize_text(prod.name)
        prod_cat_norm = normalize_text(prod.category)
        prod_attrs_text = humanize_attributes(prod.attributes)
        
        # Normalizar capacidades del producto (2L -> 2000ml)
        prod_capacity_norm = normalize_capacity(prod.name)
        if prod.attributes:
            for k, v in prod.attributes.items():
                prod_capacity_norm += " " + normalize_capacity(str(v))
        
        synonyms_list = prod.synonyms or []
        synonyms_norm = [normalize_text(s) for s in synonyms_list]
        synonyms_text = " ".join(synonyms_norm)

        full_product_text = f"{prod_name_norm} {prod_cat_norm} {prod_attrs_text} {synonyms_text} {prod_capacity_norm}"
        
        # Iteramos sobre cada "deseo" del usuario para ver si este producto encaja
        for idx, intent in enumerate(intent_items):
            score = 0
            base_name = normalize_text(intent.get("product_name", ""))
            
            # PUNTUACIÓN BASE: Coincidencia de nombre principal (+10)
            if base_name in prod_name_norm or base_name in prod_cat_norm:
                score += 10
            
            print(f"   -> Item: {prod.name} | Intent: {base_name} | Score Base: {score}")
            
            # PUNTUACIÓN SINÓNIMOS (+8)
            if any(base_name in s for s in synonyms_norm):
                score += 8
            
            # Verificación de score mínimo para continuar
            if score == 0:
                continue
            
            # FILTROS OBLIGATORIOS (must_contain): +5 por cada uno
            must_list = intent.get("must_contain", [])
            all_must_present = True
            for term in must_list:
                term_norm = normalize_text(term)
                if term_norm in full_product_text:
                    score += 5
                else:
                    all_must_present = False
                    break
            
            if not all_must_present:
                continue
            
            # FILTROS NEGATIVOS (must_not_contain)
            must_not_list = intent.get("must_not_contain", [])
            has_forbidden = False
            for term in must_not_list:
                term_norm = normalize_text(term)
                if term_norm in full_product_text:
                    has_forbidden = True
                    break
            
            if has_forbidden:
                continue
            
            # ATRIBUTOS PREFERIDOS (+3)
            preferred_list = intent.get("preferred_attributes", [])
            for pref in preferred_list:
                pref_norm = normalize_text(pref)
                pref_capacity = normalize_capacity(pref)
                
                if pref_norm in full_product_text or pref_capacity in prod_capacity_norm:
                    score += 3
            
            # UMBRAL: Mínimo 8 puntos
            if score >= 8:
                # Guardamos el intent_index (idx) para filtrar después
                scored_results.append((inv, prod, bodega, intent.get("quantity", 1), score, idx))
                # NOTA: No hacemos break aquí porque un mismo producto podría teóricamente satisfacer dos intents diferentes
                # (aunque es raro, ej: "dame una coca y una gaseosa negra")

    print(f"✨ [DEBUG] Resultados con scoring: {len(scored_results)}")
    
    # 3.5 FALLBACK (Solo si no hay NADA para un intent específico)
    # Comprobamos qué intents no tienen candidatos
    covered_intents = set(item[5] for item in scored_results)
    
    if len(covered_intents) < len(intent_items):
        print("⚠️ [FALLBACK] Algunos items no tienen match exacto, buscando similares...")
        
        for idx, intent in enumerate(intent_items):
            if idx in covered_intents: continue # Ya cubierto
            
            base_name = normalize_text(intent.get("product_name", ""))
            if not base_name: continue

            for inv, prod, bodega in raw_results:
                prod_name_norm = normalize_text(prod.name)
                prod_cat_norm = normalize_text(prod.category)
                prod_syns = [normalize_text(s) for s in (prod.synonyms or [])]
                
                # Búsqueda flexible
                if base_name in prod_name_norm or base_name in prod_cat_norm or any(base_name in s for s in prod_syns):
                    # Score bajo (5)
                    scored_results.append((inv, prod, bodega, intent.get("quantity", 1), 5, idx))

    # 4. AGRUPAMIENTO INTELIGENTE (Top 1 por Intent por Bodega)
    bodegas_map = {} # { bodega_id: { "bodega": b, "selections": { intent_idx: (score, item) } } }

    for inv, prod, bodega, qty, score, intent_idx in scored_results:
        bid = bodega.id
        if bid not in bodegas_map:
            bodegas_map[bid] = {"bodega": bodega, "selections": {}}
        
        # Lógica "Rey de la Colina": Si ya tenemos un candidato para este intent_idx en esta bodega,
        # nos quedamos con el de mayor score.
        current_selection = bodegas_map[bid]["selections"].get(intent_idx)
        
        if current_selection is None or score > current_selection[0]:
            # Guardamos el score y el item creado
            item_obj = ProductItem(
                product_id=prod.id, 
                name=prod.name, 
                price=inv.price, 
                stock=inv.stock_quantity, 
                unit=prod.default_unit or "UND",
                attributes=prod.attributes,
                requested_quantity=qty
            )
            bodegas_map[bid]["selections"][intent_idx] = (score, item_obj)

    # Convertir al formato final
    final_bodega_list = []
    
    for bid, data in bodegas_map.items():
        found_items = []
        total_price = 0.0
        
        # Recuperamos los ganadores de cada intent
        for score, item in data["selections"].values():
            found_items.append(item)
            total_price += (float(item.price) * item.requested_quantity)
        
        # Guardamos en el mapa final para el loop siguiente (que ya existía en el código original)
        # Hack para compatibilidad con código existente abajo:
        data["items"] = found_items
        data["total"] = total_price
        # El código original usa `bodegas_map` pero con otra estructura, así que ajustemos:
        # El código original iteraba `bodegas_map.items()` abajo.
        # Solo necesitamos asegurarnos que data["items"] y data["total"] existan.


    response_list = []
    found_details = [] # <--- Restauramos esto
    
    # CALCULAMOS COMPLETITUD REAL
    # completeness = items_encontrados / total_intenciones
    total_intents = len(intent_items) if intent_items else 1
    
    for bib, data in bodegas_map.items():
         found_items_list = data["items"]
         found_len = len(found_items_list)
         completeness = found_len / total_intents if total_intents > 0 else 0
         
         # Llenamos found_details para el resumen
         for item in found_items_list:
             qty_str = f" x{item.requested_quantity}" if item.requested_quantity > 1 else ""
             found_details.append(f"{item.name}{qty_str}")

         # Distancia
         dist_km = InventoryRepository.haversine(request.user_lat, request.user_lon, float(data["bodega"].latitude), float(data["bodega"].longitude))

         response_list.append(BodegaSearchResult(# ...
            bodega_id=data["bodega"].id,
            name=data["bodega"].name,
            latitude=float(data["bodega"].latitude),
            longitude=float(data["bodega"].longitude),
            distance_meters=int(dist_km * 1000),
            is_open=True,
            completeness_score=completeness * 100,
            total_price=data["total"],
            found_items=data["items"],
            missing_items=[]
        ))

    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))
    
    # Mejorar el contexto para el bot
    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))
    
    # MEJORAR CONTEXTO PARA EL BOT
    if response_list:
        top_match = response_list[0]
        # Lista de nombres de productos encontrados en TOTAL (unique)
        all_found = list(set(found_details))
        summary_products = ", ".join(all_found[:10])
        
        # 1. CASO IDEAL: Encontramos TODO en la mejor bodega
        if top_match.completeness_score >= 99:
             context_str = f"¡ÉXITO! Encontré TODO ({summary_products}) en la bodega '{top_match.name}'."
             if len(response_list) > 1:
                 context_str += f" También hay otras {len(response_list)-1} opciones."
        
        # 2. CASO PARCIAL: No hay ninguna bodega con todo junto
        else:
            context_str = f"NO encontré todo junto. Lo mejor que hallé fue '{top_match.name}' que tiene: {', '.join([i.name for i in top_match.found_items or []])}. "
            context_str += f"Productos disponibles dispersos: {summary_products}. Avisa al usuario que tendría que pedir de dos sitios o elegir."

    else:
        context_str = "No se encontraron coincidencias ni productos similares."

    
    bot_message = await gemini_client.generate_shopkeeper_response(request.query, context_str)
    
    # --- PROCESO DE GUARDADO DE RESPUESTA DEL BOT ---
    if current_session:
        # Serializar resultados para persistencia (Recomendaciones en historial)
        attachment_json = None
        if response_list:
            try:
                # Usar jsonable_encoder para manejar UUIDs, Datetimes, etc. de forma segura
                from fastapi.encoders import jsonable_encoder
                attachment_json = jsonable_encoder(response_list)
                print(f"💾 [DB] Guardando {len(attachment_json)} tarjetas de productos en historial.")
            except Exception as e:
                print(f"⚠️ Error serializando attachment: {e}")

        bot_msg_db = ChatMessage(
            session_id=current_session.id,
            role="assistant",
            content=bot_message,
            attachment_data=attachment_json # <--- NUEVO: Persistencia de tarjetas
        )
        db.add(bot_msg_db)
        
        # --- ACTUALIZAR TÍTULO DEL CHAT (Mejora UX) ---
        new_title = None
        
        # 1. Si hay productos identificados (intención de compra)
        if keywords:
            products_str = ", ".join(keywords[:2]).title()
            if len(keywords) > 2:
                products_str += "..."
            new_title = f"🛒 {products_str}"
            
        # 2. Si es una intención específica y no tiene título de producto
        elif not current_session.title or "Chat" in current_session.title:
            if intent_type == "GREETING":
                new_title = "👋 Saludo"
            elif intent_type == "QUESTION":
                new_title = "❓ Consulta"
            elif intent_type == "CLEAR_CART":
                new_title = "🗑️ Limpiando carrito"
        
        # Aplicar cambio si hay nuevo título
        if new_title:
            # Si el nuevo título es de productos, sobrescribe cualquier cosa anterior (incluso saludos)
            if "🛒" in new_title:
                current_session.title = new_title
            # Si es otro tipo, solo si no tiene título ya definido
            elif not current_session.title or "Chat" in current_session.title:
                current_session.title = new_title
        
        current_session.updated_at = func.now()
        db.commit()

    return SmartSearchResponse(
        message=bot_message,
        results=response_list,
        session_id=current_session.id if current_session else None
    )
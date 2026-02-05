from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session
from typing import List, Optional, cast
from uuid import UUID
import uuid
import shutil
import os
from app.db.session import get_db
from app.schemas.api_schemas import SearchRequest, BodegaSearchResult, ProductItem, SmartSearchResponse
from app.services.gemini_service import gemini_client
from app.repositories.inventory_repo import InventoryRepository
import json
import unicodedata
from app.core.security import decrypt_value

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

from app.models.tables import ChatSession, ChatMessage, User, Category, Bodega, MasterProduct, StoreInventory
from sqlalchemy import desc, func
from datetime import datetime, timedelta

import re

async def _parse_order_from_text(text: str, user_lat: float, user_lon: float, db: Session) -> List[BodegaSearchResult]:
    # Regex para extraer items de la confirmación
    # Formato esperado: "- 2 x Coca Cola (Bodega: Bodega Pepe) - S/ 10.00"
    pattern = r'-\s*(\d+)\s*x\s*(.+?)\s*\(Bodega:\s*(.+?)\)\s*-\s*S/\s*([\d\.]+)'
    
    matches = re.findall(pattern, text)
    if not matches:
        return []
    
    bodega_items = {}
    bodega_totals = {}
    
    for qty_str, prod_name, bod_name, total_str in matches:
        qty = int(qty_str)
        total_price = float(total_str)
        unit_price = total_price / qty if qty > 0 else 0
        
        # Buscar bodega para este item
        b_db = db.query(Bodega).filter(Bodega.name.ilike(f"%{bod_name}%")).first()
        pid = 0
        if b_db:
            print(f"🏢 [PARSER] Bodega encontrada: {b_db.name} (ID: {b_db.id})")
            # Buscar el producto maestro por nombre (más flexible)
            clean_prod_name = prod_name.strip()
            p_master = db.query(MasterProduct).filter(MasterProduct.name.ilike(clean_prod_name)).first()
            if p_master:
                print(f"📦 [PARSER] Producto maestro encontrado: {p_master.name} (ID: {p_master.id})")
                # Verificar si está en el inventario de esa bodega
                inv = db.query(StoreInventory).filter(
                    StoreInventory.bodega_id == b_db.id,
                    StoreInventory.product_id == p_master.id
                ).first()
                if inv:
                    pid = p_master.id
                    print(f"✅ [PARSER] Item en inventario confirmado. ID: {pid}")
                else:
                    print(f"❌ [PARSER] El producto {prod_name} no existe en el inventario de la bodega {bod_name}")
            else:
                print(f"❌ [PARSER] Producto maestro '{prod_name}' no encontrado en DB")
        else:
            print(f"❌ [PARSER] Bodega '{bod_name}' no encontrada en DB")
        
        if bod_name not in bodega_items:
            bodega_items[bod_name] = []
            bodega_totals[bod_name] = 0.0
            
        bodega_totals[bod_name] += total_price
        
        item = ProductItem(
            product_id=pid,
            name=prod_name,
            price=unit_price,
            stock=999,
            unit="UND",
            attributes={},
            requested_quantity=qty,
            image_url=p_master.image_url if p_master else None,
            category=p_master.category if p_master else None
        )
        bodega_items[bod_name].append(item)
        
    results = []
    for bod_name, items in bodega_items.items():
        # Buscar bodega real por nombre
        b_db = db.query(Bodega).filter(Bodega.name.ilike(f"%{bod_name}%")).first()
        
        if b_db:
             res = BodegaSearchResult(
                bodega_id=b_db.id,
                name=b_db.name,
                distance_meters=0, 
                latitude=float(b_db.latitude),
                longitude=float(b_db.longitude),
                is_open=True, # Default to True for confirmation
                completeness_score=1.0,
                total_price=bodega_totals[bod_name],
                found_items=items,
                missing_items=[]
             )
             results.append(res)
             
    return results

# NUEVO: Helper para unificar respuesta de orden
def _build_unified_order_response(search_state: List[dict], db: Session) -> dict:
    if not search_state:
        return {"message": "No hay productos en tu carrito temporal.", "results": []}
    
    grouped = {}
    total_global = 0.0
    
    for item in search_state:
        bodega_id = item.get('bodega_id')
        if not bodega_id: continue 
        
        if bodega_id not in grouped:
            bodega = db.query(Bodega).filter(Bodega.id == bodega_id).first()
            grouped[bodega_id] = {
                "bodega_name": bodega.name if bodega else "Bodega Desconocida",
                "items": [],
                "subtotal": 0.0
            }
            
        qty = item.get('quantity', 1)
        price = item.get('price', 0.0)
        subtotal = price * qty
        
        grouped[bodega_id]['items'].append({
            "name": item.get('name', 'Producto'),
            "quantity": qty,
            "unit_price": price,
            "product_id": item.get('product_id')
        })
        grouped[bodega_id]['subtotal'] += subtotal
        total_global += subtotal

    results = []
    for bid, data in grouped.items():
        res = BodegaSearchResult(
            bodega_id=bid,
            name=data['bodega_name'],
            latitude=0.0, longitude=0.0,
            distance_meters=0, is_open=True, completeness_score=1.0,
            total_price=data['subtotal'],
            found_items=[
                ProductItem(
                     name=i['name'],
                     price=i['unit_price'],
                     requested_quantity=i['quantity'],
                     stock=999, unit="UND", attributes={},
                     product_id=i.get('product_id'),
                     image_url=i.get('image_url'),
                     category=i.get('category')
                ) for i in data['items']
            ],
            missing_items=[]
        )
        results.append(res)
        
    return {
        "message": f"Aquí tienes el resumen de tu pedido (Total: S/ {total_global:.2f}).",
        "results": results
    }

@router.post("/smart/voice", response_model=SmartSearchResponse)
async def smart_search_voice(
    session_id: Optional[UUID] = None,
    user_id: Optional[str] = None,
    user_name: Optional[str] = "Usuario",
    greeting_time: Optional[str] = "Hola",
    user_lat: float = -8.0783, # Default Huanchaco
    user_lon: float = -79.1180,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Procesa audio -> Texto (Gemini) -> Búsqueda Inteligente.
    """
    try:
        # 1. Guardar audio temporal
        temp_filename = f"temp_{uuid.uuid4()}.m4a"
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        print(f"🎤 [VOICE] Audio recibido: {temp_filename}")

        # 2. Transcribir
        transcription = await gemini_client.transcribe_audio(temp_filename)
        
        # Limpiar
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
            
        if not transcription:
             return SmartSearchResponse(
                message="No pude escucharte bien. ¿Podrías repetirlo?",
                results=[],
                session_id=session_id
            )
            
        print(f"🎤 [VOICE] Texto detectado: {transcription}")
        
        # 3. Ejecutar búsqueda normal
        # Construimos el request simulate
        req = SearchRequest(
            query=transcription,
            session_id=session_id,
            user_id=user_id,
            user_name=user_name,
            greeting_time=greeting_time,
            user_lat=user_lat,
            user_lon=user_lon,
            transcription=transcription
        )
        
        return await search_smart(req, db)

    except Exception as e:
        print(f"Error voice processing: {e}")
        return SmartSearchResponse(
            message="Error procesando tu audio.",
            results=[],
            session_id=session_id
        )

@router.post("/smart", response_model=SmartSearchResponse)
async def search_smart(
    request: SearchRequest, 
    db: Session = Depends(get_db)
):
    print(f"\n📨 [INPUT] User ({request.user_id}): '{request.query}'")
    
    # 0. Obtener usuario para personalizar
    user = db.query(User).filter(User.id == request.user_id).first()
    
    # 0. DETECCIÓN COMANDO ORDEN (Antes de todo)
    if request.query and request.query.startswith("CMD_REVIEW_ORDER"):
        print("🛒 [INTENT] Detectado CMD_REVIEW_ORDER")
        try:
             # Recuperar sesión
             current_session = None
             if request.session_id:
                 current_session = db.query(ChatSession).filter(ChatSession.id == request.session_id).first()
             
             if not current_session and request.user_id:
                 current_session = ChatSession(user_id=request.user_id, is_active=True)
                 db.add(current_session)
                 db.commit()
            
             if current_session:
                 items = current_session.search_state or []
                 unified = _build_unified_order_response(items, db)
                 
                 # Guardar respuesta
                 # Guardar respuesta
                 bot_msg = ChatMessage(session_id=current_session.id, role="assistant", content=unified['message'])
                 db.add(bot_msg)
                 db.commit()
                 db.refresh(bot_msg)
                 
                 return SmartSearchResponse(
                     message=unified['message'],
                     results=unified['results'],
                     session_id=current_session.id,
                     message_id=bot_msg.id, # NUEVO
                     is_order_summary=True
                 )
        except Exception as e:
             print(f"Error reviewing order: {e}") 



    print(f"\n📍 [DEBUG] Ubicación: {request.user_lat}, {request.user_lon}")
    
    # --- 0. DATOS DE CONTEXTO (USUARIO Y HORA) ---
    user_name = "Usuario"
    greeting_time = "Hola"
    avoid_greeting = False
    
    # Hora Perú (UTC-5)
    peru_time = datetime.utcnow() - timedelta(hours=5)
    hour = peru_time.hour
    
    if 5 <= hour < 12:
        greeting_time = "Buenos días"
    elif 12 <= hour < 19:
        greeting_time = "Buenas tardes"
    else:
        greeting_time = "Buenas noches"

    # --- 1. GESTIÓN DE MEMORIA (HISTORIAL EN BD) ---
    history_for_gemini = request.conversation_history # Fallback por defecto
    current_session = None

    if request.user_id:
        print(f"👤 [API] ID DE USUARIO RECIBIDO: {request.user_id}")
        
        # A. ESTRATEGIA DE SESIÓN (STRICT MODE)
        
        # Recuperar Nombre del Usuario
        user_record = db.query(User).filter(User.id == request.user_id).first()
        if user_record and user_record.full_name:
            # Solo primer nombre
            decrypted_name = decrypt_value(user_record.full_name) or "Usuario"
            user_name = decrypted_name.strip().split()[0].title()
            print(f"👤 [API] Nombre detectado: {user_name}")

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

            # Check if conversation is active (Has the bot spoken before in this chat?)
            if current_session:
                 # Contamos mensajes previos del BOT en esta sesión
                 msg_count = db.query(ChatMessage).filter(
                     ChatMessage.session_id == current_session.id,
                     ChatMessage.role == 'assistant'
                 ).count()
                 
                 if msg_count > 0:
                     avoid_greeting = True
                     print(f"🚦 [CHAT] El bot ya ha participado en este chat ({msg_count} msgs). Omitiendo saludo.")

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

    # --- 1.5 DETECCIÓN DE CONFIRMACIÓN DE PEDIDO (BYPASS GEMINI) ---
    if "Quiero confirmar el siguiente pedido" in request.query:
        print("🛒 [INTENT] Detectado 'Confirmación de Pedido' explícito.")
        parsed_results = await _parse_order_from_text(request.query, request.user_lat, request.user_lon, db)
        
        bot_message = "¡Entendido! Aquí tienes el resumen de tu pedido listo para reservar."
        
        # Guardar respuesta del bot
        if current_session:
            # Serializamos attachment
            import json
            attachment_data = {
                "type": "reservation_preview",
                "results": [r.dict() for r in parsed_results] # Convertiral dict para JSON
            }
            # Bugfix: r.dict() might contain UUIDs not serializable. handled by json_encoders in main usually, but here we manually storing to JSONB.
            # Convert UUID to str
            def json_serial(obj):
                if isinstance(obj, UUID): return str(obj)
                raise TypeError(f"Type {type(obj)} not serializable")
            
            # Use json.loads/dumps to ensure dict format safely? 
            # Actually SQLAlchemy JSONB handles basic types. But UUID needs string.
            # We will rely on Pydantic's .json() or .dict() with proper encoders.
            # For simplicity let's rely on standard serialization if possible or just store as dict if we can.
            # But results has UUID objects.
            # Let's rely on FastApi response_model to handle output, but for DB storage we need dicts.
            
            # Simple manual conversion for now
            results_json = []
            for res in parsed_results:
                res_dict = res.dict()
                res_dict['bodega_id'] = str(res_dict['bodega_id'])
                # ProductItems don't have UUIDs usually
                results_json.append(res_dict)

            bot_msg_db = ChatMessage(
                session_id=current_session.id, 
                role="assistant", 
                content=bot_message,
                attachment_data={"type": "reservation_preview", "results": results_json}
            )
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)

        return SmartSearchResponse(
            message=bot_message,
            results=parsed_results,
            message_id=bot_msg_db.id if current_session else None, # NUEVO
            session_id=current_session.id if current_session else None,
            is_order_summary=True
        )

    # --- 2. CLASIFICACIÓN DE INTENCIÓN ---
    
    # 1. Clasificar con Gemini
    classification_result = await gemini_client.classify_intent(request.query)
    
    intent_type = classification_result.get("intent", "UNKNOWN")
    requires_search = classification_result.get("requires_search", False)
    requires_state = classification_result.get("requires_state", False)
    clear_state = classification_result.get("clear_state", False)
    is_inappropriate = classification_result.get("is_inappropriate", False)

    print(f"🧠 [INTENT] Tipo: {intent_type} | ReqSearch: {requires_search} | ReqState: {requires_state}")

    # CASO 0: Contenido inapropiado - Rechazar sin llamar a Gemini (ahorra API)
    if intent_type == "INAPPROPRIATE" or is_inappropriate:
        # Mensaje fijo para no gastar API
        bot_message = "Aea CHOLA, mejor escucha El Gran Cagón 😹😹"
        
        # Guardar advertencia pero NO respuesta elaborada
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)
        
        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None,
            message_id=bot_msg_db.id if current_session else None # NUEVO
        )
    
    # CASO A: Saludos y Despedidas - Solo responder, NO buscar productos
    if intent_type in ["GREETING", "FAREWELL", "CLARIFICATION_NEEDED"]:
        
        bot_intent = intent_type
        
        # --- NUEVO: PRE-BÚSQUEDA DE CONTEXTO PARA CLARIFICACIÓN ---
        available_catalog = ""
        if intent_type == "CLARIFICATION_NEEDED":
             # Extraemos keywords simples del query para ver qué hay disponible
             # Ej: "Coca" -> Buscamos todo lo que tenga "Coca" cerca
             raw_keywords = [w for w in request.query.split() if len(w) > 3] # Solo palabras > 3 letras
             
             if raw_keywords:
                 print(f"🔎 [CLARIFICATION-CONTEXT] Buscando contexto para: {raw_keywords}")
                 try:
                     context_products = InventoryRepository.search_products_smart(
                         db, raw_keywords, request.user_lat, request.user_lon, max_dist_km=2.0
                     )
                     
                     if context_products:
                         # Resumir productos únicos encontrados
                         unique_names = list(set([prod.name for _, prod, _ in context_products]))
                         unique_names = unique_names[:15] # Limitar a 15 para no saturar prompt
                         available_catalog = ", ".join(unique_names)
                         print(f"🔎 [CLARIFICATION-CONTEXT] Encontrados: {len(unique_names)} variantes ({available_catalog})")
                     else:
                         print("🔎 [CLARIFICATION-CONTEXT] No se encontró nada relevante cerca.")
                 except Exception as e:
                     print(f"⚠️ Error buscando contexto de clarificación: {e}")

        
        bot_message = await gemini_client.generate_conversational_response(
            request.query, 
            bot_intent, 
            user_name=user_name, 
            greeting_time=greeting_time,
            available_options=available_catalog, # <--- OPCIONES DISPONIBLES
            avoid_greeting=avoid_greeting # <--- FLAG RESTAURADO
        )
        
        # Guardar respuesta del bot
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)
        
        
        # LOG OUTPUT ADICIONAL (Para early return)
        print(f"📤 [OUTPUT] Bot Response: '{bot_message}'")
        print("📦 [OUTPUT] Offers: None (Conversational Response)")
        print("-" * 50 + "\n")

        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None,
            message_id=bot_msg_db.id if current_session else None # NUEVO
        )
    
    # CASO B: Limpiar carrito
    if intent_type == "CLEAR_CART" or clear_state:
        if current_session:
            current_session.search_state = []
            db.commit()
        
        bot_message = await gemini_client.generate_conversational_response(
             request.query, 
             "CLEAR_CART", 
             user_name=user_name,
             avoid_greeting=avoid_greeting
        )
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)
        
        
        # LOG OUTPUT ADICIONAL (Para early return)
        print(f"📤 [OUTPUT] Bot Response: '{bot_message}'")
        print("📦 [OUTPUT] Offers: None (Clear Cart)")
        print("-" * 50 + "\n")

        return SmartSearchResponse(
            message=bot_message, 
            results=[],
            session_id=current_session.id if current_session else None,
            message_id=bot_msg_db.id if current_session else None # NUEVO
        )
    
    # CASO C: Recordar pedido anterior - Solo mostrar el estado guardado
    if intent_type == "RECALL_PREVIOUS":
        if search_state:
            products_str = ", ".join([f"{p.get('quantity', 1)}x {p.get('product_name', 'producto')}" for p in search_state])
            context = f"Pedido guardado: {products_str}"
        else:
            context = "No hay pedido guardado"
        
        bot_message = await gemini_client.generate_conversational_response(
            request.query, 
            "RECALL_PREVIOUS", 
            context,
            user_name=user_name,
            avoid_greeting=avoid_greeting
        )
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=bot_message)
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)
        
        # Si hay estado, hacer búsqueda con esos productos
        if search_state:
            # Continuar con la búsqueda usando el estado guardado
            intent_items = search_state
        else:
            # LOG OUTPUT ADICIONAL (Para early return)
            print(f"📤 [OUTPUT] Bot Response: '{bot_message}'")
            print("📦 [OUTPUT] Offers: None (Recall Empty)")
            print("-" * 50 + "\n")

            return SmartSearchResponse(
                message=bot_message, 
                results=[],
                session_id=current_session.id if current_session else None,
                message_id=bot_msg_db.id if current_session else None # NUEVO
            )
    
    # CASO E: Búsqueda, Agregar, Modificar, Pregunta, Y AHORA CONFIRMACIONES - Requieren procesamiento
    else:
        # Determinar si usamos el estado anterior
        state_to_use = search_state if requires_state else []
        
        # 1.5 Recuperar último mensaje del BOT para contexto (Negotiation Memory)
        last_bot_msg_text = ""
        if current_session:
             last_msg = db.query(ChatMessage).filter(
                 ChatMessage.session_id == current_session.id,
                 ChatMessage.role == "assistant"
             ).order_by(ChatMessage.created_at.desc()).first()
             if last_msg:
                 last_bot_msg_text = last_msg.content
                 print(f"🤖 [MEMORY] Último mensaje del bot: '{last_bot_msg_text}'")

        # 2. Interpretación (Extracción de JSON) con MasterProduct Context
        known_products = []
        try:
            # Assuming MasterProduct is imported and db is a SQLAlchemy session
            known_products = [r.name for r in db.query(MasterProduct.name).limit(1000).all()]
        except Exception as e:
            print(f"Error fetching known products: {e}")

        # Llamar a interpret_search_intent con el tipo de intención Y EL CONTEXTO
        updated_state = await gemini_client.interpret_search_intent(
            request.query, 
            state_to_use, 
            intent_type=intent_type,
            known_products=known_products,
            last_bot_message=last_bot_msg_text
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
        msg = await gemini_client.generate_shopkeeper_response(
            request.query, 
            "Sin intención clara de producto, intenta ayudar.",
            user_name=user_name,
            avoid_greeting=avoid_greeting
        )
        
        if current_session:
            bot_msg_db = ChatMessage(session_id=current_session.id, role="assistant", content=msg)
            db.add(bot_msg_db)
            db.commit()
            db.refresh(bot_msg_db)
        
        return SmartSearchResponse(
            message=msg, 
            results=[], 
            message_id=bot_msg_db.id if current_session else None # NUEVO
        )

    # 2. Buscar en BD
    raw_results = InventoryRepository.search_products_smart(
        db, keywords, request.user_lat, request.user_lon, max_dist_km=0.9
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
            
            # ATRIBUTOS PREFERIDOS (NUEVA LÓGICA ESTRICTA)
            preferred_list = intent.get("preferred_attributes", [])
            
            # Regla de extracción de unidades
            import re
            def extract_qty_unit(text):
                # Matches: 3L, 3 L, 2.5kg, 250 g, 3 latas, 500ml
                match = re.search(r'(\d+(?:\.\d+)?)\s*(l|ml|kg|gr?|oz|un|latas?|botellas?)', text, re.IGNORECASE)
                if match:
                    u = match.group(2).lower()
                    # Normalizar unidades
                    if u in ['gr', 'g', 'gramos']: u = 'g'
                    if u in ['l', 'lt', 'litro', 'litros']: u = 'l'
                    if u in ['ml', 'mililitros']: u = 'ml'
                    if u in ['kg', 'kilo', 'kilos']: u = 'kg'
                    return float(match.group(1)), u
                return None, None

            strict_penalty = False
            attribute_boost = 0
            
            # Extraer specs del PRODUCTO
            # Concatenamos atributos para buscar mejor
            import json as _json_lib
            prod_full_desc = f"{prod.name} {prod.default_unit or ''} {_json_lib.dumps(prod.attributes or {})}"
            prod_qty, prod_unit = extract_qty_unit(prod_full_desc)
            
            for pref in preferred_list:
                pref_qty, pref_unit = extract_qty_unit(pref)
                
                if pref_qty is not None and pref_unit is not None:
                    # EL USUARIO PIDIÓ CANTIDAD ESPECÍFICA (Ej: 3 L)
                    
                    if prod_qty is not None:
                        # El producto TAMBIÉN tiene cantidad
                        if pref_unit == prod_unit:
                            if abs(pref_qty - prod_qty) < 0.1: 
                                # COINCIDENCIA EXACTA (3L == 3L) -> BOOST MASIVO
                                attribute_boost += 50
                            else: 
                                # MISMA UNIDAD, DIFERENTE CANTIDAD (3L vs 1.5L) -> PENALIZAR
                                strict_penalty = True
                        
                        # Conversiones básicas (L vs ml / kg vs g)
                        # 3 L vs 3000 ml
                        elif (pref_unit == 'l' and prod_unit == 'ml'): 
                             if abs(pref_qty * 1000 - prod_qty) < 1.0: attribute_boost += 50
                             else: strict_penalty = True
                        elif (pref_unit == 'ml' and prod_unit == 'l'): 
                             if abs(pref_qty - prod_qty * 1000) < 1.0: attribute_boost += 50
                             else: strict_penalty = True
                        elif (pref_unit == 'kg' and prod_unit == 'g'): 
                             if abs(pref_qty * 1000 - prod_qty) < 1.0: attribute_boost += 50
                             else: strict_penalty = True
                        elif (pref_unit == 'g' and prod_unit == 'kg'): 
                             if abs(pref_qty - prod_qty * 1000) < 1.0: attribute_boost += 50
                             else: strict_penalty = True
                    
                    else:
                        # Usuario pide 3L, producto no dice nada claro. No penalizar, pero no boost.
                        pass
                
                
                # Fallback de texto simple (Marcas, Tipos, Sabores)
                else:
                    pref_norm = normalize_text(pref)
                    # Si el atributo es significativo (>2 chars) y NO está en el producto -> PENALIZAR
                    if len(pref_norm) > 2:
                        if pref_norm in full_product_text:
                            attribute_boost += 5
                        else:
                            # CRÍTICO: Si el usuario pidió explícitamente "Faraón" y no está -> NO ES MATCH PERFECTO
                            strict_penalty = True
                            print(f"   ⚠️ Atributo faltante: '{pref_norm}' -> Penalty Applied")
            
            if strict_penalty:
                # MARKER: Esto es un "Partial Match" (Negotiation Item)
                # No lo penalizamos con -100, sino que lo marcamos especial.
                score = 5 # Score bajo pero positivo para que entre
                is_negotiation = True
                print(f"   PARTIAL MATCH: {prod.name} (Penalty Applied) -> Score: {score}")
            else:
                score += attribute_boost
                is_negotiation = False
                print(f"   PERFECT MATCH: {prod.name} -> Score: {score}")
            
            # UMBRAL: Mínimo 5 puntos (ahora permitimos partials)
            if score >= 5:
                scored_results.append((inv, prod, bodega, intent.get("quantity", 1), score, idx, is_negotiation))

    print(f"✨ [DEBUG] Resultados con scoring: {len(scored_results)}")
    
    # 3.5 FALLBACK (Solo si no hay NADA para un intent específico)
    covered_intents = set(item[5] for item in scored_results)
    
    if len(covered_intents) < len(intent_items):
        print("⚠️ [FALLBACK] Algunos items no tienen match exacto, buscando similares...")
        for idx, intent in enumerate(intent_items):
            if idx in covered_intents: continue
            base_name = normalize_text(intent.get("product_name", ""))
            if not base_name: continue
            for inv, prod, bodega in raw_results:
                prod_name_norm = normalize_text(prod.name)
                prod_cat_norm = normalize_text(prod.category)
                prod_syns = [normalize_text(s) for s in (prod.synonyms or [])]
                if base_name in prod_name_norm or base_name in prod_cat_norm or any(base_name in s for s in prod_syns):
                    scored_results.append((inv, prod, bodega, intent.get("quantity", 1), 5, idx, False)) # False? Maybe True if fallback? Let's say False for now to show results.

    # 4. AGRUPAMIENTO INTELIGENTE (Top 1 por Intent por Bodega)
    bodegas_map = {} 

    for inv, prod, bodega, qty, score, intent_idx, is_negotiation in scored_results:
        bid = bodega.id
        if bid not in bodegas_map:
            bodegas_map[bid] = {"bodega": bodega, "selections": {}, "negotiations": []}
        
        # Lógica "Rey de la Colina"
        current_selection = bodegas_map[bid]["selections"].get(intent_idx)
        
        if is_negotiation:
             # Si es negociación, lo guardamos en una lista aparte para contexto, NO reemplaza al principal si existe
             bodegas_map[bid]["negotiations"].append({
                 "name": prod.name,
                 "reason": "Different Size/Variant",
                 "intent_idx": intent_idx
             })
             print(f"   🗳️ Guardado como NEGOTIATION ITEM: {prod.name} en Bodega {bodega.name}")
             # AUNQUE... si es la única opción, quizás deberíamos trackearla?
             # Por ahora, "Partial Matches" NO entran al carrito automático. Solo al texto.
             continue

        if current_selection is None or score > current_selection[0]:
            print(f"   🏆 Ganador TEMPORAL para intent {intent_idx}: {prod.name} (Score: {score}) en Bodega {bodega.name}")
            item_obj = ProductItem(
                product_id=prod.id, 
                name=prod.name, 
                price=inv.price, 
                stock=inv.stock_quantity, 
                unit=prod.default_unit or "UND",
                attributes=prod.attributes,
                requested_quantity=qty,
                image_url=prod.image_url,
                category=prod.category
            )
            bodegas_map[bid]["selections"][intent_idx] = (score, item_obj)

    # Convertir al formato final
    response_list = []
    
    for bib, data in bodegas_map.items():
         found_items_list = []
         total_price = 0.0
         
         for score, item in data["selections"].values():
             found_items_list.append(item)
             total_price += (float(item.price) * item.requested_quantity)
         
         # Calcular completitud (Solo perfect matches cuentan)
         found_len = len(found_items_list)
         completeness = found_len / len(intent_items) if intent_items else 0
         
         # Distancia
         dist_km = InventoryRepository.haversine(request.user_lat, request.user_lon, float(data["bodega"].latitude), float(data["bodega"].longitude))

         # Preparamos contexto de negociación para esta bodega
         negotiation_context = list(set([n["name"] for n in data["negotiations"]])) # Unique names
         
         # Hack: Adjuntar datos extra al objeto (aunque no esté en el schema, Python lo permite runtime, o usamos un campo hidden)
         # Schema BodegaSearchResult no tiene 'negotiation_context'. Lo usaremos solo para el prompt aquí.
         
         res_obj = BodegaSearchResult(
            bodega_id=data["bodega"].id,
            name=data["bodega"].name,
            latitude=float(data["bodega"].latitude),
            longitude=float(data["bodega"].longitude),
            distance_meters=int(dist_km * 1000),
            is_open=True,
            completeness_score=completeness * 100,
            total_price=total_price,
            found_items=found_items_list,
            missing_items=[]
        )
         
         response_list.append(res_obj)

    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))
    
    # MEJORAR CONTEXTO PARA EL BOT
    if response_list:
        top_match = response_list[0]
        found_names = [f"{i.requested_quantity}x {i.name}" for i in top_match.found_items]
        
        context_str = f"Mejor opción: Bodega '{top_match.name}'.\n"
        
        if found_names:
            context_str += f"Precio Total del Carrito: S/ {top_match.total_price:.2f} (REFERENCIAL).\n"
            context_str += f"Items ENCONTRADOS y AGREGADOS al carrito: {', '.join(found_names)}.\n"
            context_str += "INSTRUCCIÓN: Si hay items ENCONTRADOS, CONFIRMA que ya están listos/agregados. NO preguntes '¿Los agrego?'. Dí 'Listo, agregué X. Sale S/ Y'."
        else:
            context_str += "Items ENCONTRADOS EXACTOS: NINGUNO.\n"
            context_str += "INSTRUCCIÓN: NO DIGAS QUE AGREGASTE NADA. DI QUE NO ENCONTRASTE EL PRODUCTO EXACTO.\n"
        
        # FIX: Recuperar negotiations desde el mapa original usando el ID de la mejor bodega
        # No podemos adjuntar atributos a Pydantic runtime sin config especial, mejor consultamos la fuente.
        top_bodega_data = bodegas_map.get(top_match.bodega_id)
        negotiation_list = []
        if top_bodega_data and "negotiations" in top_bodega_data:
             negotiation_list = list(set([n["name"] for n in top_bodega_data["negotiations"]]))
            
        if negotiation_list:
            context_str += f"Items PARCIALES (NO AGREGADOS, SUGERIR AL USUARIO): {', '.join(negotiation_list)}.\n"
            context_str += "INSTRUCCIÓN: Di claramente que NO hay el exacto, pero ofreces los PARCIALES como alternativa. Pregunta si quiere agregarlas."
        
        if top_match.completeness_score < 100 and not negotiation_list and not found_names:
             context_str += "Faltan productos y no encontré alternativas cercanas."

    else:
        context_str = "No se encontraron coinciciencias en bodegas cercanas."
    
    bot_message = await gemini_client.generate_shopkeeper_response(
        request.query, 
        context_str,
        user_name=user_name,
        avoid_greeting=avoid_greeting
    )
    
    # LOG OUTPUT FINAL
    print(f"📤 [OUTPUT] Bot Response: '{bot_message}'")
    
    # ... (Resto del guardado igual) ...
    if current_session:
        # Serializar resultados para persistencia (Recomendaciones en historial)
        
        # FIX: Filtrar tarjetas vacías SOLO para el frontend/DB
        # El bot usó la lista completa (incluyendo partials vacíos), pero el UI no debe mostrar eso.
        ui_response_list = [res for res in response_list if res.found_items]
        
        attachment_json = None
        if ui_response_list:
            try:
                # Usar jsonable_encoder para manejar UUIDs, Datetimes, etc. de forma segura
                from fastapi.encoders import jsonable_encoder
                attachment_json = jsonable_encoder(ui_response_list)
                print(f"💾 [DB] Guardando {len(attachment_json)} tarjetas de productos en historial (Filtradas).")
            except Exception as e:
                print(f"⚠️ Error serializando attachment: {e}")

        bot_msg_db = ChatMessage(
            session_id=current_session.id,
            role="assistant",
            content=bot_message,
            attachment_data=attachment_json # <--- NUEVO: Persistencia de tarjetas FILTRADAS
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

    # Asegurar que ui_response_list esté definida (por si no entró al bloque current_session)
    if 'ui_response_list' not in locals():
        ui_response_list = [res for res in response_list if res.found_items]

    # LOG DE OFERTAS
    if ui_response_list:
        print(f"📦 [OUTPUT] Offers ({len(ui_response_list)} items):")
        for res in ui_response_list:
             items_str = ", ".join([i.name for i in res.found_items])
             print(f"   - {res.name}: {items_str} (Score: {res.completeness_score:.1f}%)")
    else:
        print("📦 [OUTPUT] Offers: None (Active Negotiation or No Match)")
    print("-" * 50 + "\n")

    return SmartSearchResponse(
        message=bot_message,
        results=ui_response_list, # <--- FIX: Retornar lista FILTRADA
        session_id=current_session.id if current_session else None
    )


# --- NUEVO ENDPOINT PARA TIENDA VISUAL (MAPA) ---
from pydantic import BaseModel
from typing import List
import math
from app.models.tables import Bodega, MasterProduct, StoreInventory, User, Category  # Asegurar imports
from sqlalchemy import or_

class VisualStoreItem(BaseModel):
    product_name: str
    image_url: str | None
    price: float
    bodega_name: str
    distance_meters: int
    bodega_lat: float
    bodega_lon: float
    product_id: int
    bodega_id: str

@router.get("/visual-store", response_model=List[VisualStoreItem])
async def get_visual_store_products(
    category: str, 
    lat: float, 
    lon: float, 
    radius_km: float = 0.9, 
    db: Session = Depends(get_db)
):
    print(f"🌍 [VISUAL] Buscando '{category}' cerca de {lat},{lon} (Radio: {radius_km}km)")
    
    # Optimización: Bounding Box para filtro SQL rápido
    # 1 grado lat ~= 111km
    lat_range = radius_km / 111.0
    # Ajuste por latitud para longitud
    lon_range = radius_km / (111.0 * abs(math.cos(math.radians(lat)))) if abs(math.cos(math.radians(lat))) > 0.0001 else lat_range

    min_lat = lat - lat_range
    max_lat = lat + lat_range
    min_lon = lon - lon_range
    max_lon = lon + lon_range

    query = (
        db.query(
            MasterProduct.name.label("product_name"),
            MasterProduct.image_url,
            StoreInventory.price,
            Bodega.name.label("bodega_name"),
            Bodega.latitude,
            Bodega.longitude,
            MasterProduct.id.label("product_id"),
            Bodega.id.label("bodega_id")
        )
        .join(StoreInventory, MasterProduct.id == StoreInventory.product_id)
        .join(Bodega, StoreInventory.bodega_id == Bodega.id)
        .join(User, Bodega.owner_id == User.id) # Para verificar si el usuario/bodega está activo
        .outerjoin(Category, MasterProduct.category_id == Category.id)
        .filter(
            or_(Category.name.ilike(f"%{category}%"), MasterProduct.category.ilike(f"%{category}%")),
            StoreInventory.stock_quantity > 0,
            User.is_active == True, # Requisito: bodega activa (usamos owner activo)
            Bodega.latitude.between(min_lat, max_lat),
            Bodega.longitude.between(min_lon, max_lon)
        )
    )
    
    results = query.all()
    
    final_items = []
    
    for row in results:
        # Cálculo fino de distancia (Haversine real)
        dist_km_real = InventoryRepository.haversine(lat, lon, float(row.latitude), float(row.longitude))
        
        if dist_km_real <= radius_km:
            final_items.append(VisualStoreItem(
                product_name=row.product_name,
                image_url=row.image_url,
                price=float(row.price),
                bodega_name=row.bodega_name,
                distance_meters=int(dist_km_real * 1000),
                bodega_lat=float(row.latitude),
                bodega_lon=float(row.longitude),
                product_id=row.product_id,
                bodega_id=str(row.bodega_id)
            ))
            
    final_items.sort(key=lambda x: x.distance_meters)
    
    print(f"✅ [VISUAL] Encontrados {len(final_items)} items")
    return final_items

# --- CATEGORÍAS ---
@router.get("/categories")
def get_categories(db: Session = Depends(get_db)):
    """Retorna todas las categorías disponibles para el slider."""
    cats = db.query(Category).all()
    results = []
    
    # Icon map fallback
    icon_map = {
        "Bebidas": "local_drink",
        "Abarrotes": "shopping_basket",
        "Limpieza": "cleaning_services",
        "Cuidado Personal": "face",
        "Snacks": "fastfood",
        "Lácteos": "egg_alt",
        "Otros": "category"
    }

    for c in cats:
        icon_str = c.icon_name if c.icon_name else icon_map.get(c.name, "store")
        results.append({
            "name": c.name,
            "icon_name": icon_str
        })
        
    return results
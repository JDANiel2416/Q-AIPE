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

# -------------------

@router.post("/smart", response_model=SmartSearchResponse)
async def search_smart(request: SearchRequest, db: Session = Depends(get_db)):
    
    print(f"\n📍 [DEBUG] Ubicación: {request.user_lat}, {request.user_lon}")

    # 1. Interpretar intención (Gemini devuelve cantidades)
    intent_items = await gemini_client.interpret_search_intent(
        request.query, 
        request.conversation_history
    )
    
    # Extraemos keywords
    keywords = [item.get("product_name", "") for item in intent_items]
    print(f"🤖 [DEBUG] Keywords base: {keywords}")

    if not keywords:
        msg = await gemini_client.generate_shopkeeper_response(request.query, "Sin intención clara.")
        return SmartSearchResponse(message=msg, results=[])

    # 2. Buscar en BD
    raw_results = InventoryRepository.search_products_smart(
        db, keywords, request.user_lat, request.user_lon
    )

    # 3. FILTRADO INTELIGENTE + ASIGNACIÓN DE CANTIDAD
    filtered_results = []
    
    for inv, prod, bodega in raw_results:
        # Normalizamos textos
        prod_name_norm = normalize_text(prod.name)
        prod_cat_norm = normalize_text(prod.category)
        prod_attrs_text = humanize_attributes(prod.attributes)
        
        synonyms_list = prod.synonyms or []
        synonyms_norm = [normalize_text(s) for s in synonyms_list]
        synonyms_text = " ".join(synonyms_norm)

        full_product_text = f"{prod_name_norm} {prod_cat_norm} {prod_attrs_text} {synonyms_text}"
        
        matches_any_intent = False 
        matched_qty = 1 # Por defecto es 1
        
        for intent in intent_items:
            base_name = normalize_text(intent.get("product_name", ""))
            
            # Coincidencia Básica
            is_match_base = (
                base_name in prod_name_norm or 
                base_name in prod_cat_norm or 
                base_name in prod_attrs_text or 
                any(base_name in s for s in synonyms_norm)
            )

            if is_match_base:
                matches_this_intent = True 
                
                # Filtros POSITIVOS
                must_list = intent.get("must_contain", [])
                for term in must_list:
                    if normalize_text(term) not in full_product_text:
                        matches_this_intent = False
                        break
                
                if not matches_this_intent: continue

                # Filtros NEGATIVOS
                must_not_list = intent.get("must_not_contain", [])
                for term in must_not_list:
                    if normalize_text(term) in full_product_text:
                        matches_this_intent = False
                        break
                
                if not matches_this_intent: continue

                # ¡COINCIDENCIA TOTAL! Capturamos la cantidad
                matches_any_intent = True
                matched_qty = intent.get("quantity", 1) # <--- AQUÍ CAPTURAMOS EL 2 o 3
                break 
        
        if matches_any_intent:
            # Guardamos la tupla con la cantidad: (inv, prod, bodega, QTY)
            filtered_results.append((inv, prod, bodega, matched_qty))

    print(f"✨ [DEBUG] Resultados finales: {len(filtered_results)}")

    # 4. Agrupar resultados
    bodegas_map = {}
    # Desempaquetamos la nueva variable qty
    for inv, prod, bodega, qty in filtered_results:
        if bodega.id not in bodegas_map:
            bodegas_map[bodega.id] = {"bodega": bodega, "items": [], "total": 0.0}
        
        bodegas_map[bodega.id]["items"].append(ProductItem(
            product_id=prod.id, 
            name=prod.name, 
            price=inv.price, 
            stock=inv.stock_quantity, 
            unit=prod.default_unit or "UND",
            attributes=prod.attributes,
            requested_quantity=qty # <--- ENVIAMOS AL FRONTEND
        ))
        # Opcional: Podrías multiplicar precio * qty para el total estimado
        bodegas_map[bodega.id]["total"] += (float(inv.price) * qty)

    response_list = []
    found_details = []

    for bid, data in bodegas_map.items():
        found = data["items"]
        completeness = len(found) / len(keywords) if keywords else 0
        
        for item in found:
            attrs_str = humanize_attributes(item.attributes)
            # Agregamos la cantidad al resumen del bot también
            qty_str = f"x{item.requested_quantity}" if item.requested_quantity > 1 else ""
            found_details.append(f"{item.name} {attrs_str} {qty_str}")

        dist_km = InventoryRepository.haversine(request.user_lat, request.user_lon, float(data["bodega"].latitude), float(data["bodega"].longitude))
        
        response_list.append(BodegaSearchResult(
            bodega_id=data["bodega"].id,
            name=data["bodega"].name,
            latitude=float(data["bodega"].latitude),
            longitude=float(data["bodega"].longitude),
            distance_meters=int(dist_km * 1000),
            is_open=True,
            completeness_score=completeness * 100,
            total_price=data["total"],
            found_items=found,
            missing_items=[]
        ))

    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))
    
    summary_products = ", ".join(list(set(found_details))[:10]) 
    context_str = f"Se encontraron {len(response_list)} bodegas. Productos: {summary_products}." if response_list else "No se encontraron coincidencias."
    
    bot_message = await gemini_client.generate_shopkeeper_response(request.query, context_str)

    return SmartSearchResponse(message=bot_message, results=response_list)
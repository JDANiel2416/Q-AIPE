from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.api_schemas import SearchRequest, BodegaSearchResult, ProductItem, SmartSearchResponse
from app.services.gemini_service import gemini_client
from app.repositories.inventory_repo import InventoryRepository

router = APIRouter()

@router.post("/smart", response_model=SmartSearchResponse)
async def search_smart(request: SearchRequest, db: Session = Depends(get_db)):
    
    print(f"\n📍 [DEBUG] Ubicación recibida: {request.user_lat}, {request.user_lon}")

    # 1. Interpretar intención
    intent_json = await gemini_client.interpret_search_intent(
        request.query, 
        request.conversation_history
    )
    keywords = [item.get("product_name", "") for item in intent_json]
    print(f"🤖 [DEBUG] Gemini keywords: {keywords}")

    if not keywords:
        msg = await gemini_client.generate_shopkeeper_response(
            request.query, 
            "El cliente solo está conversando."
        )
        return SmartSearchResponse(message=msg, results=[])

    # 2. Buscar en BD (Radio 1.5km por defecto)
    raw_results = InventoryRepository.search_products_smart(
        db, keywords, request.user_lat, request.user_lon
    )
    print(f"🔎 [DEBUG] BD encontró {len(raw_results)} filas.")

    # 3. Agrupar resultados
    bodegas_map = {}
    for inv, prod, bodega in raw_results:
        if bodega.id not in bodegas_map:
            bodegas_map[bodega.id] = {"bodega": bodega, "items": [], "total": 0.0}
        
        # --- FIX 1: AGREGAR LOS ATRIBUTOS AQUÍ ---
        # Antes faltaba 'attributes=prod.attributes', por eso llegaba vacío.
        bodegas_map[bodega.id]["items"].append(ProductItem(
            product_id=prod.id, 
            name=prod.name, 
            price=inv.price, 
            stock=inv.stock_quantity, 
            unit=prod.default_unit or "UND",
            attributes=prod.attributes  # <--- ¡LA PIEZA FALTANTE! 🧩
        ))
        bodegas_map[bodega.id]["total"] += float(inv.price)

    response_list = []
    all_found_products = set()

    for bid, data in bodegas_map.items():
        found = data["items"]
        completeness = len(found) / len(keywords) if keywords else 0
        
        for item in found:
            all_found_products.add(item.name)

        # --- FIX 2: CALCULAR DISTANCIA REAL ---
        # Usamos la misma función del repo para mostrar la distancia exacta en la tarjeta
        dist_km = InventoryRepository.haversine(
            request.user_lat, request.user_lon, 
            float(data["bodega"].latitude), float(data["bodega"].longitude)
        )
        dist_meters = int(dist_km * 1000)

        response_list.append(BodegaSearchResult(
            bodega_id=data["bodega"].id,
            name=data["bodega"].name,
            latitude=float(data["bodega"].latitude),
            longitude=float(data["bodega"].longitude),
            distance_meters=dist_meters, # <--- Ahora mostrará 200m, 500m, etc.
            is_open=True,
            completeness_score=completeness * 100,
            total_price=data["total"],
            found_items=found,
            missing_items=[]
        ))

    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))

    # 4. Respuesta Humana
    if response_list:
        context_str = f"Se encontraron {len(response_list)} bodegas. Productos: {', '.join(all_found_products)}."
    else:
        context_str = "No se encontraron bodegas cercanas con stock exacto."

    bot_message = await gemini_client.generate_shopkeeper_response(request.query, context_str)

    return SmartSearchResponse(message=bot_message, results=response_list)
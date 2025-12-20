from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.api_schemas import SearchRequest, BodegaSearchResult, ProductItem, SmartSearchResponse
from app.services.gemini_service import gemini_client
from app.repositories.inventory_repo import InventoryRepository

router = APIRouter()

@router.post("/smart", response_model=SmartSearchResponse)
async def search_smart(request: SearchRequest, db: Session = Depends(get_db)):
    # 1. Interpretar intención CON HISTORIAL
    intent_json = await gemini_client.interpret_search_intent(
        request.query, 
        request.conversation_history # <--- Pasamos el contexto
    )
    
    keywords = [item.get("product_name", "") for item in intent_json]
    
    # Caso charla (sin productos)
    if not keywords:
        msg = await gemini_client.generate_shopkeeper_response(
            request.query, 
            "El cliente solo está conversando, no hay intención de compra clara aún."
        )
        return SmartSearchResponse(message=msg, results=[])

    # 2. Buscar en BD (Esto ya busca en TODAS las bodegas)
    raw_results = InventoryRepository.search_products_smart(
        db, keywords, request.user_lat, request.user_lon
    )

    # 3. Agrupar resultados
    bodegas_map = {}
    for inv, prod, bodega in raw_results:
        if bodega.id not in bodegas_map:
            bodegas_map[bodega.id] = {"bodega": bodega, "items": [], "total": 0.0}
        
        bodegas_map[bodega.id]["items"].append(ProductItem(
            product_id=prod.id, name=prod.name, price=inv.price, 
            stock=inv.stock_quantity, unit=prod.default_unit or "UND"
        ))
        bodegas_map[bodega.id]["total"] += float(inv.price)

    response_list = []
    all_found_products = set()

    for bid, data in bodegas_map.items():
        found = data["items"]
        completeness = len(found) / len(keywords) if keywords else 0
        
        for item in found:
            all_found_products.add(item.name)

        response_list.append(BodegaSearchResult(
            bodega_id=data["bodega"].id,
            name=data["bodega"].name,
            distance_meters=100, 
            is_open=True,
            completeness_score=completeness * 100,
            total_price=data["total"],
            found_items=found,
            missing_items=[]
        ))

    response_list.sort(key=lambda x: (-x.completeness_score, x.total_price))

    # 4. Contexto para la respuesta humana
    if response_list:
        context_str = f"Se encontraron resultados en {len(response_list)} bodegas. Productos hallados: {', '.join(all_found_products)}."
    else:
        context_str = "No se encontraron bodegas con stock para esos productos exactos."

    bot_message = await gemini_client.generate_shopkeeper_response(request.query, context_str)

    return SmartSearchResponse(message=bot_message, results=response_list)
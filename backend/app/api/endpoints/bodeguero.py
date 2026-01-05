from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.tables import User, Bodega, StoreInventory, MasterProduct
from pydantic import BaseModel

router = APIRouter()

# Esquema para recibir el cambio de stock
class StockUpdate(BaseModel):
    product_id: int
    in_stock: bool

@router.get("/my-inventory")
def get_my_inventory(user_id: str, db: Session = Depends(get_db)):
    # 1. Buscar al usuario y su bodega
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.role != "BODEGUERO":
        raise HTTPException(status_code=403, detail="No eres bodeguero")
    
    bodega = db.query(Bodega).filter(Bodega.owner_id == user.id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No tienes una bodega asignada")

    # 2. Traer su inventario
    inventory = db.query(StoreInventory, MasterProduct)\
        .join(MasterProduct, StoreInventory.product_id == MasterProduct.id)\
        .filter(StoreInventory.bodega_id == bodega.id)\
        .all()

    # 3. Formatear respuesta
    results = []
    for inv, prod in inventory:
        results.append({
            "product_id": prod.id,
            "name": prod.name,
            "price": float(inv.price),
            "stock": inv.stock_quantity,
            "in_stock": inv.stock_quantity > 0 # Si es mayor a 0, está disponible
        })
    return results

@router.post("/toggle-stock")
def toggle_stock(user_id: str, update: StockUpdate, db: Session = Depends(get_db)):
    # 1. Buscar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Buscar el item en el inventario
    item = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == update.product_id
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Producto no encontrado en tu tienda")

    # 3. Actualizar lógica (Si es true -> Ponemos 10, si es false -> Ponemos 0)
    #    Así mantenemos la lógica simple por ahora.
    item.stock_quantity = 50 if update.in_stock else 0
    db.commit()
    
    return {"success": True, "new_stock": item.stock_quantity}
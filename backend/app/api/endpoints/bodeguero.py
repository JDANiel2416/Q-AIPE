from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.tables import User, Bodega, StoreInventory, MasterProduct
from app.schemas.api_schemas import ProductCreateRequest
from pydantic import BaseModel

router = APIRouter()

# Esquema para recibir el cambio de stock
class StockUpdate(BaseModel):
    product_id: int
    in_stock: bool

# Esquema para actualizar producto existente
class ProductUpdateRequest(BaseModel):
    product_name: str
    category: str
    price: float
    stock: int

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
            "in_stock": inv.is_available # Estado real de disponibilidad
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

    # 3. Actualizar el estado de disponibilidad (NO el stock)
    item.is_available = update.in_stock
    db.commit()
    
    return {"success": True, "is_available": item.is_available}

@router.post("/add-product")
def add_custom_product(
    user_id: str, 
    product_data: ProductCreateRequest, 
    db: Session = Depends(get_db)
):
    # 1. Validar Bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No tienes bodega")

    # 2. Verificar si el MasterProduct ya existe (por Nombre y Categoría)
    #    Para evitar crear "Coca Cola" 20 veces.
    existing_master = db.query(MasterProduct).filter(
        MasterProduct.name == product_data.name,
        MasterProduct.category == product_data.category
    ).first()

    master_id = None

    if existing_master:
        # Si existe, verificamos si YA lo tiene en su inventario
        existing_inv = db.query(StoreInventory).filter(
            StoreInventory.bodega_id == bodega.id,
            StoreInventory.product_id == existing_master.id
        ).first()

        if existing_inv:
            # CONFLICTO: Ya lo tiene, no debemos duplicarlo
            raise HTTPException(
                status_code=409, # Conflict
                detail=f"El producto '{product_data.name}' ya está en tu inventario."
            )
        
        # Si existe el maestro pero NO en su inventario, usamos ese ID
        master_id = existing_master.id
    else:
        # No existe, lo creamos
        new_master = MasterProduct(
            name=product_data.name,
            category=product_data.category,
            attributes=product_data.attributes, 
            default_unit="UND"
        )
        db.add(new_master)
        db.commit()
        db.refresh(new_master)
        master_id = new_master.id

    # 3. Agregarlo al inventario de la bodega
    new_inventory = StoreInventory(
        bodega_id=bodega.id,
        product_id=master_id,
        price=product_data.price,
        stock_quantity=product_data.stock,
        is_available=True
    )
    db.add(new_inventory)
    db.commit()

    return {"success": True, "product_id": master_id, "message": "Producto agregado correctamente"}

@router.put("/update-product")
def update_existing_product(
    user_id: str,
    update_data: ProductUpdateRequest,
    db: Session = Depends(get_db)
):
    # 1. Validar Bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No tienes bodega")

    # 2. Buscar el MasterProduct
    existing_master = db.query(MasterProduct).filter(
        MasterProduct.name == update_data.product_name,
        MasterProduct.category == update_data.category
    ).first()

    if not existing_master:
        raise HTTPException(status_code=404, detail="Producto no encontrado en el catálogo")

    # 3. Buscar en el inventario de la bodega
    existing_inv = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == existing_master.id
    ).first()

    if not existing_inv:
        raise HTTPException(status_code=404, detail="Producto no encontrado en tu inventario")

    # 4. Actualizar precio y stock
    existing_inv.price = update_data.price
    existing_inv.stock_quantity = update_data.stock
    existing_inv.is_available = True
    db.commit()

    return {"success": True, "message": "Producto actualizado correctamente"}
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

# NUEVO: Esquema para actualizar por ID
class ProductUpdateByIdRequest(BaseModel):
    product_id: int
    price: float
    stock_to_add: int  # Cantidad a SUMAR al stock actual

# Esquema para actualizar perfil
class ProfileUpdateRequest(BaseModel):
    email: str
    phone_number: str
    bodega_name: str

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
            "category": prod.category,  # AÑADIDO: Campo de categoría
            "price": float(inv.price),
            "stock": inv.stock_quantity,
            "in_stock": inv.is_available # Estado real de disponibilidad
        })
    
    return {
        "bodega_name": bodega.name,
        "products": results
    }

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

# NUEVO ENDPOINT: Actualizar por ID de producto
@router.put("/update-product-by-id")
def update_product_by_id(
    user_id: str,
    update_data: ProductUpdateByIdRequest,
    db: Session = Depends(get_db)
):
    # 1. Validar Bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No tienes bodega")

    # 2. Buscar en el inventario de la bodega por product_id
    existing_inv = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == update_data.product_id
    ).first()

    if not existing_inv:
        raise HTTPException(status_code=404, detail="Producto no encontrado en tu inventario")

    # 3. Actualizar precio y SUMAR al stock
    existing_inv.price = update_data.price
    existing_inv.stock_quantity += update_data.stock_to_add  # SUMA en lugar de reemplazar
    existing_inv.is_available = True
    db.commit()

    return {
        "success": True, 
        "message": "Producto actualizado correctamente",
        "new_stock": existing_inv.stock_quantity
    }

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

# NUEVO: Obtener perfil del bodeguero
@router.get("/profile")
def get_profile(user_id: str, db: Session = Depends(get_db)):
    # 1. Buscar usuario
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # 2. Buscar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user.id).first()
    
    # Construir URL completa de la foto si existe
    photo_url = None
    if bodega and bodega.photo_url:
        # Asumiendo que estamos en local, puedes ajustar el dominio base luego
        # O devolver solo la ruta relativa y que el front le pegue la base
        photo_url = bodega.photo_url 

    return {
        "user_id": str(user.id),
        "full_name": user.full_name or "",
        "email": user.email or "",
        "phone_number": user.phone_number or "",
        "dni": user.dni or "",
        "bodega_name": bodega.name if bodega else "",
        "bodega_address": bodega.address if bodega else "",
        "profile_photo_url": photo_url
    }

# NUEVO: Actualizar perfil
@router.put("/update-profile")
def update_profile(
    user_id: str,
    profile_data: ProfileUpdateRequest,
    db: Session = Depends(get_db)
):
    # 1. Buscar usuario
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # 2. Actualizar datos de usuario
    user.email = profile_data.email
    user.phone_number = profile_data.phone_number
    
    # 3. Buscar y actualizar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user.id).first()
    if bodega:
        bodega.name = profile_data.bodega_name
    
    db.commit()
    
    return {
        "success": True,
        "message": "Perfil actualizado correctamente"
    }

from fastapi import UploadFile, File
import shutil
import os
import uuid

@router.post("/upload-photo")
async def upload_profile_photo(
    user_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Buscar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No se encontró la bodega para este usuario")

    # 2. Guardar archivo
    # Asegurar que existe el directorio
    upload_dir = "static/images/profiles"
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generar nombre único
    file_extension = file.filename.split(".")[-1]
    filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = f"{upload_dir}/{filename}"
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # 3. Actualizar BD con URL relativa
    # Ojo: la URL accesible sería /static/images/profiles/nombre.jpg
    relative_url = f"/static/images/profiles/{filename}"
    bodega.photo_url = relative_url
    db.commit()
    
    return {
        "success": True,
        "message": "Foto actualizada",
        "photo_url": relative_url
    }

from app.models.tables import Reservation, ReservationItem
from pydantic import BaseModel

# NUEVO: Obtener pedidos de la bodega
@router.get("/orders")
def get_orders(user_id: str, db: Session = Depends(get_db)):
    # 1. Buscar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Obtener reservas ordenadas por fecha reciente
    orders = db.query(Reservation).filter(
        Reservation.bodega_id == bodega.id
    ).order_by(Reservation.created_at.desc()).all()

    # Formatear respuesta
    result = []
    for order in orders:
        # Serializar items
        items_data = [
            {
                "product_name": item.product_name,
                "quantity": item.quantity,
                "unit_price": float(item.unit_price),
                "total_price": float(item.total_price)
            }
            for item in order.items
        ]

        result.append({
            "id": str(order.id),
            "created_at": order.created_at.isoformat(),
            "client_name": order.user.full_name if order.user else "Cliente Anónimo",
            "total_amount": float(order.total_amount),
            "status": order.status,
            "items": items_data
        })

    return result

class OrderStatusUpdate(BaseModel):
    status: str # PAID, CREDIT, CANCELLED

@router.put("/orders/{order_id}/status")
def update_order_status(
    order_id: str, 
    status_data: OrderStatusUpdate,
    db: Session = Depends(get_db)
):
    order = db.query(Reservation).filter(Reservation.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")
    
    order.status = status_data.status
    db.commit()
    
    return {"success": True, "message": f"Pedido actualizado a {status_data.status}"}
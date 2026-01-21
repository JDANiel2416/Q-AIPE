from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from datetime import datetime, timedelta
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
    
    # AUTOMATION: Reactivar si hay stock positivo
    if existing_inv.stock_quantity > 0:
        existing_inv.is_available = True
    elif existing_inv.stock_quantity <= 0:
        # Por seguridad, si restan y baja a 0
        existing_inv.stock_quantity = 0
        existing_inv.is_available = False

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

# NUEVO: Obtener un pedido específico por ID (para navegación desde notificaciones)
@router.get("/orders/{order_id}")
def get_order_by_id(order_id: str, db: Session = Depends(get_db)):
    order = db.query(Reservation).filter(Reservation.id == order_id).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")
    
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
    
    return {
        "id": str(order.id),
        "created_at": order.created_at.isoformat(),
        "client_name": order.user.full_name if order.user else "Cliente Anónimo",
        "total_amount": float(order.total_amount),
        "status": order.status,
        "items": items_data
    }

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

@router.delete("/delete-product")
def delete_product(user_id: str, product_id: int, db: Session = Depends(get_db)):
    # 1. Validar Bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Buscar el item en el inventario
    item = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == product_id
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Producto no encontrado en tu tienda")

    # 3. Eliminar del inventario
    db.delete(item)
    db.flush() # Para que el cambio se refleje antes de consultar

    # 4. Verificar si el MasterProduct sigue siendo usado por ALGUIEN
    # (Si nadie más lo tiene, lo borramos para no llenar basura)
    is_used_elsewhere = db.query(StoreInventory).filter(
        StoreInventory.product_id == product_id
    ).first()

    if not is_used_elsewhere:
        # Nadie más lo usa, borrar del maestro
        master_prod = db.query(MasterProduct).filter(MasterProduct.id == product_id).first()
        if master_prod:
            db.delete(master_prod)

    db.commit()
    
    return {"success": True, "message": "Producto eliminado permanentemente"}

# NUEVO: Estadísticas del Dashboard
@router.get("/dashboard-stats")
def get_dashboard_stats(user_id: str, db: Session = Depends(get_db)):
    """
    Obtiene estadísticas reales para el panel de control del bodeguero:
    - Ganancias del día
    - Cantidad de pedidos del día
    - Pedidos activos (PENDING)
    - Ventas mensuales del año
    - Producto más vendido
    - Producto menos vendido
    """
    # 1. Buscar bodega del usuario
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Fecha actual (inicio y fin del día)
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    # 3. Ganancias del día (solo pedidos PAID/COMPLETED)
    earnings_today = db.query(func.coalesce(func.sum(Reservation.total_amount), 0)).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.status.in_(["PAID", "COMPLETED"]),
        Reservation.created_at >= today_start,
        Reservation.created_at < today_end
    ).scalar()

    # 4. Cantidad de pedidos del día (todos los estados)
    orders_today = db.query(func.count(Reservation.id)).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.created_at >= today_start,
        Reservation.created_at < today_end
    ).scalar()

    # 5. Pedidos activos (PENDING) con detalles
    pending_orders = db.query(Reservation).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.status == "PENDING"
    ).order_by(Reservation.created_at.desc()).limit(10).all()

    pending_orders_data = []
    for order in pending_orders:
        items_summary = ", ".join([
            f"{item.quantity}x {item.product_name}" 
            for item in order.items[:3]  # Máximo 3 items en resumen
        ])
        if len(order.items) > 3:
            items_summary += f" (+{len(order.items) - 3} más)"
        
        # Calcular tiempo relativo
        time_diff = datetime.now() - order.created_at
        if time_diff.days > 0:
            time_ago = f"Hace {time_diff.days} día(s)"
        elif time_diff.seconds >= 3600:
            hours = time_diff.seconds // 3600
            time_ago = f"Hace {hours} hora(s)"
        else:
            minutes = max(1, time_diff.seconds // 60)
            time_ago = f"Hace {minutes} min"
        
        pending_orders_data.append({
            "id": str(order.id),
            "client_name": order.user.full_name if order.user else "Cliente Anónimo",
            "items_summary": items_summary,
            "total_amount": float(order.total_amount),
            "time_ago": time_ago,
            "created_at": order.created_at.isoformat(),
            "status": order.status,
            "items": [
                {
                    "product_name": item.product_name,
                    "quantity": item.quantity,
                    "unit_price": float(item.unit_price),
                    "total_price": float(item.total_price)
                }
                for item in order.items
            ]
        })

    # 6. Ventas mensuales del año actual
    current_year = datetime.now().year
    monthly_sales = []
    for month in range(1, 13):
        month_total = db.query(func.coalesce(func.sum(Reservation.total_amount), 0)).filter(
            Reservation.bodega_id == bodega.id,
            Reservation.status.in_(["PAID", "COMPLETED"]),
            extract('year', Reservation.created_at) == current_year,
            extract('month', Reservation.created_at) == month
        ).scalar()
        monthly_sales.append({
            "month": month,
            "total": float(month_total) if month_total else 0.0
        })

    # 7. Productos más y menos vendidos (basado en ReservationItem)
    product_sales = db.query(
        ReservationItem.product_name,
        func.sum(ReservationItem.quantity).label('total_qty')
    ).join(Reservation).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.status.in_(["PAID", "COMPLETED"])
    ).group_by(ReservationItem.product_name).order_by(
        func.sum(ReservationItem.quantity).desc()
    ).all()

    best_selling = product_sales[0].product_name if product_sales else None
    least_selling = product_sales[-1].product_name if len(product_sales) > 1 else None

    return {
        "earnings_today": float(earnings_today) if earnings_today else 0.0,
        "orders_today": orders_today or 0,
        "pending_orders_count": len(pending_orders_data),
        "pending_orders": pending_orders_data,
        "monthly_sales": monthly_sales,
        "best_selling_product": best_selling,
        "least_selling_product": least_selling,
        "current_year": current_year
    }
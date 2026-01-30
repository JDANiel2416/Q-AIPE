from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, extract
from datetime import datetime, timedelta
from app.db.session import get_db
from app.services.gemini_service import gemini_client
from app.models.tables import User, Bodega, StoreInventory, MasterProduct, Category, SubCategory
from app.core.security import encrypt_value, decrypt_value

from app.schemas.api_schemas import ProductCreateRequest
from pydantic import BaseModel

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

# NUEVO: Esquema para estado
class BodegaStatusUpdate(BaseModel):
    is_open: bool


router = APIRouter()

# Endpoint para listar categorías (Dynamic Frontend)
@router.get("/categories")
def get_all_categories(db: Session = Depends(get_db)):
    # Retornamos objetos completos para que el frontend tenga el ID
    cats = db.query(Category).all()
    return [{"id": c.id, "name": c.name, "icon": c.icon_name} for c in cats]

@router.get("/categories/{category_id}/subcategories")
def get_subcategories_by_cat(category_id: int, db: Session = Depends(get_db)):
    subcats = db.query(SubCategory).filter(SubCategory.category_id == category_id).all()
    return [{"id": s.id, "name": s.name} for s in subcats]

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
        "bodega_id": str(bodega.id),
        "bodega_name": bodega.name,
        "is_open": bodega.manual_override == 'OPEN',
        "products": results
    }

@router.post("/toggle-stock")
def toggle_stock(user_id: str, update: StockUpdate, db: Session = Depends(get_db)):
    # 1. Buscar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Buscar el item en el inventario
    # BLOQUEO PESIMISTA: evita race conditions en actualizaciones concurrentes
    item = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == update.product_id
    ).with_for_update().first()

    if not item:
        raise HTTPException(status_code=404, detail="Producto no encontrado en tu tienda")

    # 3. Actualizar el estado de disponibilidad (NO el stock)
    item.is_available = update.in_stock
    db.commit()
    
    return {"success": True, "is_available": item.is_available}

# ...

@router.get("/master-products/search")
def search_master_products(
    q: str, 
    db: Session = Depends(get_db)
):
    """
    Busca productos en el catálogo maestro por nombre.
    Retorna resultados limitados para autocompletado.
    """
    if not q or len(q) < 2:
        return []
    
    # Búsqueda case-insensitive
    results = db.query(MasterProduct).filter(
        MasterProduct.name.ilike(f"%{q}%")
    ).limit(10).all()
    
    output = []
    for p in results:
        # Recuperar nombres de cat/subcat si existen relaciones
        cat_name = p.category
        if p.category_obj:
            cat_name = p.category_obj.name
            
        sub_name = None
        if p.subcategory_obj:
            sub_name = p.subcategory_obj.name

        output.append({
            "id": p.id,
            "name": p.name,
            "category": cat_name,
            "subcategory": sub_name,
            "image_url": p.image_url,
            "default_unit": p.default_unit,
            "attributes": p.attributes
        })
        
    return output

@router.post("/add-product")
async def add_custom_product(
    user_id: str, 
    product_data: ProductCreateRequest, 
    db: Session = Depends(get_db)
):
    # 1. Validar Bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="No tienes bodega")

    # 1.5. Gestionar Categoría (Buscamos o Creamos)
    # Normalizamos nombre (ej: "Bebidas" en lugar de "bebidas")
    cat_name = product_data.category.strip().title() if product_data.category else "Otros"
    
    category_obj = db.query(Category).filter(Category.name == cat_name).first()
    if not category_obj:
        # Si no existe, la creamos al vuelo
        # Icono por defecto
        icon = "category_outlined"
        if "Bebida" in cat_name: icon = "local_drink_outlined"
        elif "Abarrote" in cat_name: icon = "shopping_basket_outlined"
        elif "Limpieza" in cat_name: icon = "cleaning_services_outlined"

        category_obj = Category(name=cat_name, icon_name=icon)
        db.add(category_obj)
        db.flush()

    # 2. Gestionar Master Product
    master_id = product_data.master_product_id
    master_p = None

    if master_id:
        # Caso A: Seleccionó uno existente
        master_p = db.query(MasterProduct).filter(MasterProduct.id == master_id).first()
        if not master_p:
            raise HTTPException(status_code=404, detail="Producto maestro no encontrado")
    else:
        # Caso B: Producto Nuevo (Validar con IA)
        # 2.1. Verificar duplicado exacto por nombre primero
        existing_master = db.query(MasterProduct).filter(
            MasterProduct.name == product_data.name
        ).first()

        if existing_master:
            master_p = existing_master
            master_id = existing_master.id
        else:
            # 2.2. Validación IA
            validation = await gemini_client.validate_product_name(product_data.name)
            if not validation.get("is_valid", True):
                raise HTTPException(
                    status_code=400, 
                    detail=f"Nombre rechazado por seguridad: {validation.get('reason')}"
                )

            # 2.3. Crear nuevo MasterProduct
            new_master = MasterProduct(
                name=product_data.name,
                category=category_obj.name,
                category_id=category_obj.id,
                subcategory_id=product_data.subcategory_id,
                attributes=product_data.attributes,
                default_unit="un" # Default simple
            )
            db.add(new_master)
            db.flush() # Para obtener ID
            master_p = new_master
            master_id = new_master.id

    # 3. Vincular a Inventario (Upsert)
    existing_inv = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == master_id
    ).first()

    if existing_inv:
        return JSONResponse(
            status_code=409, 
            content={
                "detail": f"El producto '{product_data.name}' ya está en tu inventario.",
                "product_id": master_id
            }
        )


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
    # BLOQUEO PESIMISTA: evita race conditions en actualizaciones concurrentes de stock
    existing_inv = db.query(StoreInventory).filter(
        StoreInventory.bodega_id == bodega.id,
        StoreInventory.product_id == update_data.product_id
    ).with_for_update().first()

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
        "email": decrypt_value(user.email) or "",
        "phone_number": decrypt_value(user.phone_number) or "",
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
    user.email = encrypt_value(profile_data.email)
    user.phone_number = encrypt_value(profile_data.phone_number)
    
    # 3. Buscar y actualizar bodega
    bodega = db.query(Bodega).filter(Bodega.owner_id == user.id).first()
    if bodega:
        bodega.name = profile_data.bodega_name
    
    db.commit()
    
    return {
        "success": True,
        "message": "Perfil actualizado correctamente"
    }

@router.put("/status")
def update_bodega_status(
    user_id: str,
    status_data: BodegaStatusUpdate,
    db: Session = Depends(get_db)
):
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")
    
    bodega.manual_override = 'OPEN' if status_data.is_open else 'CLOSED'
    db.commit()
    
    return {"success": True, "is_open": status_data.is_open}

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
    
    previous_status = order.status
    new_status = status_data.status
    
    # RESTAURAR STOCK SI SE CANCELA UN PEDIDO PENDIENTE
    if new_status == "CANCELLED" and previous_status == "PENDING":
        # Iterar por cada item del pedido y restaurar el stock
        for item in order.items:
            # Buscar el producto en el inventario
            # Usamos with_for_update para evitar race conditions
            inventory_item = db.query(StoreInventory).filter(
                StoreInventory.bodega_id == order.bodega_id,
                StoreInventory.product_id == db.query(MasterProduct.id).filter(
                    MasterProduct.name == item.product_name
                ).scalar()
            ).with_for_update().first()
            
            if inventory_item:
                # Restaurar la cantidad al stock
                inventory_item.stock_quantity += item.quantity
                
                # Reactivar el producto si estaba desactivado por falta de stock
                if inventory_item.stock_quantity > 0:
                    inventory_item.is_available = True
                
                print(f"✅ Stock restaurado: +{item.quantity} de '{item.product_name}'")
    
    order.status = new_status
    db.commit()
    
    message = f"Pedido actualizado a {new_status}"
    if new_status == "CANCELLED" and previous_status == "PENDING":
        message += " (stock restaurado)"
    
    return {"success": True, "message": message}

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

    # 6. Ventas de la semana actual (Lunes a Domingo)
    today = datetime.now()
    # Calcular el lunes de esta semana
    monday = today - timedelta(days=today.weekday())
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    
    weekly_sales = []
    day_names = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    
    for i in range(7):
        day_start = monday + timedelta(days=i)
        day_end = day_start + timedelta(days=1)
        
        day_total = db.query(func.coalesce(func.sum(Reservation.total_amount), 0)).filter(
            Reservation.bodega_id == bodega.id,
            Reservation.status.in_(["PAID", "COMPLETED"]),
            Reservation.created_at >= day_start,
            Reservation.created_at < day_end
        ).scalar()
        
        weekly_sales.append({
            "day": i,
            "day_name": day_names[i],
            "total": float(day_total) if day_total else 0.0
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

    # 8. NUEVO: Total de dinero fiado (pedidos con status CREDIT)
    total_credit = db.query(func.coalesce(func.sum(Reservation.total_amount), 0)).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.status == "CREDIT"
    ).scalar()

    return {
        "earnings_today": float(earnings_today) if earnings_today else 0.0,
        "orders_today": orders_today or 0,
        "pending_orders_count": len(pending_orders_data),
        "pending_orders": pending_orders_data,
        "weekly_sales": weekly_sales,  # Cambiado de monthly_sales
        "best_selling_product": best_selling,
        "least_selling_product": least_selling,
        "total_credit": float(total_credit) if total_credit else 0.0
    }

# NUEVO: Endpoint para obtener lista de deudores (clientes que deben dinero)
@router.get("/debtors")
def get_debtors(user_id: str, db: Session = Depends(get_db)):
    """
    Obtiene la lista de clientes que tienen pedidos fiados (status CREDIT).
    Agrupa por cliente y suma el total que debe cada uno.
    """
    # 1. Buscar bodega del usuario
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Obtener pedidos con status CREDIT agrupados por cliente
    debtors_query = db.query(
        User.id.label('user_id'),
        User.full_name.label('client_name'),
        User.phone_number.label('phone'),
        func.sum(Reservation.total_amount).label('total_debt'),
        func.count(Reservation.id).label('orders_count')
    ).join(Reservation, User.id == Reservation.user_id).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.status == "CREDIT"
    ).group_by(User.id, User.full_name, User.phone_number).order_by(
        func.sum(Reservation.total_amount).desc()
    ).all()

    # 3. Formatear respuesta
    debtors_list = []
    total_credit = 0.0
    
    for debtor in debtors_query:
        debt_amount = float(debtor.total_debt) if debtor.total_debt else 0.0
        total_credit += debt_amount
        
        debtors_list.append({
            "user_id": str(debtor.user_id),
            "client_name": debtor.client_name or "Cliente Anónimo",
            "phone": decrypt_value(debtor.phone) or "",
            "total_debt": debt_amount,
            "orders_count": debtor.orders_count
        })

    return {
        "total_credit": total_credit,
        "debtors_count": len(debtors_list),
        "debtors": debtors_list
    }

# NUEVO: Obtener detalle de pedidos fiados de un cliente específico
@router.get("/debtors/{debtor_id}/orders")
def get_debtor_orders(debtor_id: str, user_id: str, db: Session = Depends(get_db)):
    """
    Obtiene el detalle de todos los pedidos fiados de un cliente específico.
    Incluye productos, cantidades, precios al momento de la compra, y fechas.
    """
    # 1. Buscar bodega del usuario (bodeguero)
    bodega = db.query(Bodega).filter(Bodega.owner_id == user_id).first()
    if not bodega:
        raise HTTPException(status_code=404, detail="Bodega no encontrada")

    # 2. Obtener información del deudor
    debtor = db.query(User).filter(User.id == debtor_id).first()
    if not debtor:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    # 3. Obtener todos los pedidos CREDIT de este cliente en esta bodega
    orders = db.query(Reservation).filter(
        Reservation.bodega_id == bodega.id,
        Reservation.user_id == debtor_id,
        Reservation.status == "CREDIT"
    ).order_by(Reservation.created_at.desc()).all()

    # 4. Formatear respuesta con detalle de cada pedido
    orders_list = []
    total_debt = 0.0

    for order in orders:
        order_total = float(order.total_amount)
        total_debt += order_total
        
        # Formatear fecha y hora
        created_at = order.created_at
        date_str = created_at.strftime("%d/%m/%Y")
        time_str = created_at.strftime("%H:%M")
        
        # Items con precio al momento de la compra
        items_data = [
            {
                "product_name": item.product_name,
                "quantity": item.quantity,
                "unit_price": float(item.unit_price),  # Precio cuando lo compró
                "total_price": float(item.total_price)
            }
            for item in order.items
        ]
        
        orders_list.append({
            "order_id": str(order.id),
            "date": date_str,
            "time": time_str,
            "created_at": created_at.isoformat(),
            "total_amount": order_total,
            "items": items_data
        })

    return {
        "debtor_id": debtor_id,
        "client_name": debtor.full_name or "Cliente Anónimo",
        "phone": debtor.phone_number or "",
        "total_debt": total_debt,
        "orders_count": len(orders_list),
        "orders": orders_list
    }

@router.post("/scan-magic")
async def scan_magic_product(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Escanea un producto con IA, extrae datos y busca coincidencias en el catálogo maestro.
    """
    try:
        # 1. Leer contenido del archivo
        content = await file.read()
        
        # 2. Obtener TAXONOMÍA REAL de la base de datos
        categories = db.query(Category).options(joinedload(Category.subcategories)).all()
        
        # Construir string dinámico para el prompt
        taxonomy_lines = []
        for cat in categories:
            sub_names = [s.name for s in cat.subcategories]
            # Formato: - CATEGORIA: [Sub1, Sub2, Sub3]
            taxonomy_lines.append(f"- {cat.name.upper()}: [{', '.join(sub_names)}]")
        
        taxonomy_str = "\n".join(taxonomy_lines)
        
        # 3. Analizar con Gemini (con taxonomía inyectada)
        ai_data = await gemini_client.analyze_product_image(
            image_bytes=content,
            mime_type=file.content_type or "image/jpeg",
            taxonomy=taxonomy_str 
        )
        
        # 4. Buscar coincidencia en MasterProduct
        found_master_id = None
        suggested_name = ai_data.get("suggested_name")
        
        if suggested_name:
            # Búsqueda por similitud de nombre (case insensitive)
            match = db.query(MasterProduct).filter(
                MasterProduct.name.ilike(f"%{suggested_name}%")
            ).first()
            
            if match:
                found_master_id = match.id
                
        return {
            "found_master_id": found_master_id,
            "ai_data": ai_data
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"❌ Error en scan-magic: {e}")
        return JSONResponse(
            status_code=500,
            content={"detail": f"Error interno: {str(e)}"}
        )

@router.post("/scan-bulk")
async def scan_bulk_products(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Escaneo masivo: Detecta múltiples productos e inyecta la taxonomía real.
    """
    content = await file.read()
    
    # 1. Fetch Taxonomía Real (Blocking call, but fast enough for this size)
    categories = db.query(Category).options(joinedload(Category.subcategories)).all()
    
    # 2. Construir string de taxonomía
    # Formato: 
    # - BEBIDAS: [Gaseosa, Agua, Cerveza]
    taxonomy_lines = []
    for cat in categories:
        sub_names = [s.name for s in cat.subcategories]
        if not sub_names:
            sub_names = ["General"]
        taxonomy_lines.append(f"- {cat.name.upper()}: [{', '.join(sub_names)}]")
    
    taxonomy_str = "\n".join(taxonomy_lines)

    # 3. Llamar a Gemini con contexto
    products = await gemini_client.analyze_bulk_products(
        image_bytes=content,
        mime_type=file.content_type or "image/jpeg",
        taxonomy=taxonomy_str
    )
    
    return {"products": products}
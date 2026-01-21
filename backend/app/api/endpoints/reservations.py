from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.tables import Reservation, ReservationItem, User, Bodega
from pydantic import BaseModel
from typing import List
import uuid

router = APIRouter()

class ReservationItemSchema(BaseModel):
    product_id: int
    product_name: str
    quantity: int
    unit_price: float

class CreateReservationRequest(BaseModel):
    user_id: str
    bodega_id: str
    items: List[ReservationItemSchema]

@router.post("/create")
async def create_reservation(request: CreateReservationRequest, db: Session = Depends(get_db)):
    try:
        # 1. Validar Usuario y Bodega
        user = db.query(User).filter(User.id == request.user_id).first()
        bodega = db.query(Bodega).filter(Bodega.id == request.bodega_id).first()
        
        if not user or not bodega:
            raise HTTPException(status_code=404, detail="Usuario o Bodega no encontrados")

        # 2. Calcular Totales
        total_amount = sum(item.quantity * item.unit_price for item in request.items)
        
        # 3. Crear Reserva
        reservation_id = uuid.uuid4()
        # Generamos un string simple para el QR por ahora (ID de reserva)
        qr_data = f"RES|{reservation_id}|{total_amount}" 
        
        new_reservation = Reservation(
            id=reservation_id,
            user_id=request.user_id,
            bodega_id=request.bodega_id,
            total_amount=total_amount,
            status="PENDING",  # Pendiente hasta que bodeguero confirme
            qr_code_data=qr_data
        )
        db.add(new_reservation)
        db.flush() # Para obtener el ID si fuera autoincrement (aquí ya lo tenemos)

        # 4. Crear Items y Descontar Stock
        from app.models.tables import StoreInventory # Importar modelo

        for item in request.items:
            # Buscar el producto en el inventario de la bodega
            inventory_item = db.query(StoreInventory).filter(
                StoreInventory.bodega_id == request.bodega_id,
                StoreInventory.product_id == item.product_id
            ).first()

            if not inventory_item:
                raise HTTPException(status_code=400, detail=f"El producto '{item.product_name}' no existe en esta bodega.")
            
            if inventory_item.stock_quantity < item.quantity:
                raise HTTPException(status_code=400, detail=f"Stock insuficiente para '{item.product_name}'. Disponible: {inventory_item.stock_quantity}")

            # Descontar stock
            inventory_item.stock_quantity -= item.quantity
            
            # AUTOMATION: Desactivar si stock llega a 0
            if inventory_item.stock_quantity <= 0:
                inventory_item.is_available = False
                inventory_item.stock_quantity = 0 # Asegurar no negativos

            db_item = ReservationItem(
                reservation_id=reservation_id,
                product_name=item.product_name,
                quantity=item.quantity,
                unit_price=item.unit_price,
                total_price=item.quantity * item.unit_price
            )
            db.add(db_item)
        
        db.commit()

        # 5. Notificación al Bodeguero (Simulada / Log)
        # Formato: "Nombre Completo + Inicial Apellido"
        full_name_parts = (user.full_name or "Cliente").split()
        if len(full_name_parts) >= 2:
            formatted_name = f"{full_name_parts[0]} {full_name_parts[1][0]}."
        else:
            formatted_name = user.full_name or "Cliente"

        items_summary = ", ".join([f"{i.quantity}x {i.product_name}" for i in request.items])
        
        
        notification_msg = (
            f"🔔 [NUEVO PEDIDO] {formatted_name} ha reservado: {items_summary}. "
            f"Total: S/{total_amount:.2f}"
        )
        print(f"\n📨 ENVIANDO NOTIFICACIÓN A BODEGUERO ({bodega.name}):\n{notification_msg}\n")

        # --- NOTIFICACIÓN PUSH FCM ---
        from app.services.push_service import send_push_notification
        
        # Obtener el usuario bodeguero (dueño de la bodega)
        bodeguero = db.query(User).filter(User.id == bodega.owner_id).first()
        
        # IMPORTANTE: Solo enviar si:
        # 1. El bodeguero existe y tiene token FCM
        # 2. El bodeguero NO es el mismo usuario que hizo el pedido (evitar auto-notificación)
        # 3. El token del bodeguero es diferente al del cliente (evitar mismo dispositivo)
        if bodeguero and bodeguero.fcm_token:
            # Verificar que no sea el mismo usuario
            if str(bodeguero.id) == str(request.user_id):
                print(f"⚠️ El bodeguero es el mismo que el cliente, no se envía notificación")
            # Verificar que no sea el mismo dispositivo
            elif user.fcm_token and bodeguero.fcm_token == user.fcm_token:
                print(f"⚠️ Cliente y bodeguero usan el mismo dispositivo, no se envía notificación")
            else:
                await send_push_notification(
                    fcm_token=bodeguero.fcm_token,
                    title="¡Nuevo Pedido Recibido!",
                    body=f"{formatted_name} ha realizado un pedido de S/{total_amount:.2f}",
                    data={
                        "type": "NEW_ORDER",
                        "reservation_id": str(reservation_id),
                        "total": float(total_amount)
                    }
                )
                print(f"✅ Notificación enviada a bodeguero: {bodeguero.full_name}")
        else:
            print(f"⚠️ Bodeguero sin FCM token registrado, no se puede enviar push")
        # ------------------------------

        return {
            "success": True,
            "reservation_id": str(reservation_id),
            "qr_data": qr_data,
            "message": "Reserva creada exitosamente",
            "formatted_name": formatted_name,
            "total": total_amount,
            "items": request.items
        }

    except Exception as e:
        db.rollback()
        print(f"Error creating reservation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

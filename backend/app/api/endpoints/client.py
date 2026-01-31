from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from app.db.session import get_db
from app.models.tables import User, ChatSession, ChatMessage, Reservation, ReservationItem
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta
import uuid
from app.core.security import decrypt_value

router = APIRouter()

# --- HELPER: Generar títulos descriptivos ---
def generate_chat_title(search_state: list, created_at: datetime, message_count: int) -> str:
    """
    Genera un título descriptivo para el chat.
    Formato: 🛒 Producto1 y Producto2 - 14:30
    """
    now = datetime.now()
    
    # Formatear fecha/hora
    if created_at.date() == now.date():
        time_str = created_at.strftime("%H:%M")
    elif created_at.date() == (now - timedelta(days=1)).date():
        time_str = f"Ayer {created_at.strftime('%H:%M')}"
    else:
        time_str = created_at.strftime("%d/%m %H:%M")
    
    # Si no hay productos buscados
    if not search_state:
        if message_count == 0:
            return f"💬 Chat nuevo - {time_str}"
        return f"💬 Conversación - {time_str}"
    
    # Extraer nombres de productos
    products = [item.get("product_name", "") for item in search_state[:2]]
    products = [p for p in products if p]
    
    if not products:
        return f"💬 Chat - {time_str}"
    
    # Formatear productos
    if len(products) == 1:
        product_text = products[0]
    else:
        product_text = f"{products[0]} y {products[1]}"
    
    # Agregar indicador si hay más productos
    if len(search_state) > 2:
        product_text += f" (+{len(search_state) - 2})"
    
    return f"🛒 {product_text} - {time_str}"


# --- SCHEMAS ---
class ChatSessionResponse(BaseModel):
    id: str
    title: Optional[str]
    created_at: datetime
    message_count: int
    last_message: Optional[str]

class ChatMessagesResponse(BaseModel):
    session_id: str
    title: Optional[str]
    messages: List[dict]

class OrderResponse(BaseModel):
    id: str
    bodega_name: str
    total_amount: float
    status: str
    created_at: datetime
    items: List[dict]

class UserProfileResponse(BaseModel):
    id: str
    first_name: str
    full_name: str
    phone: Optional[str]
    email: Optional[str]
    is_verified: bool


# --- ENDPOINTS ---

@router.get("/profile")
def get_user_profile(user_id: str, db: Session = Depends(get_db)):
    """Obtener perfil del usuario (nombre, etc.)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # Extraer primer nombre y primer apellido
    # Extraer primer nombre y primer apellido
    decrypted_full_name = decrypt_value(user.full_name) or "Usuario"
    name_parts = decrypted_full_name.split()
    
    if len(name_parts) >= 2:
        first_name = f"{name_parts[0]} {name_parts[1]}"  # Primer nombre + primer apellido
    else:
        first_name = name_parts[0] if name_parts else "Usuario"
    
    return {
        "id": str(user.id),
        "first_name": first_name,
        "full_name": decrypt_value(user.full_name), # 🔓 Desencriptar
        "phone": decrypt_value(user.phone_number),
        "email": decrypt_value(user.email),
        "is_verified": user.is_verified
    }


@router.get("/chats")
def get_user_chats(user_id: str, include_empty: bool = False, db: Session = Depends(get_db)):
    """
    Listar chats del usuario ordenados por fecha (más reciente primero).
    Por defecto NO incluye chats vacíos (sin mensajes).
    """
    sessions = db.query(ChatSession).filter(
        ChatSession.user_id == user_id
    ).order_by(desc(ChatSession.updated_at)).limit(50).all()
    
    result = []
    for session in sessions:
        msg_count = len(session.messages)
        
        # Filtrar chats vacíos si no se solicitan explícitamente
        # EXCEPTO el chat activo (siempre se muestra)
        if not include_empty and msg_count == 0 and not session.is_active:
            continue
        
        # Obtener último mensaje del usuario
        last_user_msg = None
        for msg in reversed(session.messages):
            if msg.role == "user":
                last_user_msg = msg.content[:50] + "..." if len(msg.content) > 50 else msg.content
                break
        
        # Generar título descriptivo mejorado
        title = session.title
        if not title:
            title = generate_chat_title(
                session.search_state or [], 
                session.created_at,
                msg_count
            )
        
        result.append({
            "id": str(session.id),
            "title": title,
            "created_at": session.created_at.isoformat(),
            "updated_at": session.updated_at.isoformat() if session.updated_at else session.created_at.isoformat(),
            "message_count": msg_count,
            "last_message": last_user_msg,
            "is_current": session.is_active,  # Renombrado para mayor claridad
            "has_products": bool(session.search_state)
        })
    
    return result


@router.post("/chats/new")
def create_new_chat_session(user_id: str, db: Session = Depends(get_db)):
    """Crear una nueva sesión de chat (desactiva las anteriores)"""
    
    # 1. Generar título y desactivar todas las sesiones anteriores
    prev_sessions = db.query(ChatSession).filter(
        ChatSession.user_id == user_id,
        ChatSession.is_active == True
    ).all()
    
    for session in prev_sessions:
        session.is_active = False
        # Si no tiene título, generarlo ahora
        if not session.title:
            session.title = generate_chat_title(
                session.search_state or [],
                session.created_at,
                len(session.messages)
            )
    
    # 2. Crear nueva sesión vacía
    new_session = ChatSession(
        user_id=user_id,
        search_state=[],
        is_active=True,
        title=None  # Se generará cuando se use
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    return {
        "session_id": str(new_session.id),
        "message": "Nueva sesión creada"
    }


@router.put("/chats/{session_id}/activate")
def activate_chat_session(session_id: str, user_id: str, db: Session = Depends(get_db)):
    """
    Activar un chat específico (lo marca como actual).
    Desactiva cualquier otro chat que estuviera activo.
    """
    # Verificar que el chat existe y pertenece al usuario
    session = db.query(ChatSession).filter(
        ChatSession.id == session_id,
        ChatSession.user_id == user_id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Chat no encontrado")
    
    # Desactivar todos los otros chats del usuario
    db.query(ChatSession).filter(
        ChatSession.user_id == user_id,
        ChatSession.is_active == True,
        ChatSession.id != session_id
    ).update({"is_active": False})
    
    # Generar títulos para los chats desactivados que no tienen
    prev_sessions = db.query(ChatSession).filter(
        ChatSession.user_id == user_id,
        ChatSession.title == None,
        ChatSession.id != session_id
    ).all()
    
    for prev in prev_sessions:
        if prev.search_state or len(prev.messages) > 0:
            prev.title = generate_chat_title(
                prev.search_state or [],
                prev.created_at,
                len(prev.messages)
            )
    
    # Activar el chat seleccionado
    session.is_active = True
    db.commit()
    
    return {
        "session_id": str(session.id),
        "title": session.title or generate_chat_title(
            session.search_state or [],
            session.created_at,
            len(session.messages)
        ),
        "message": "Chat activado"
    }


@router.delete("/chats/{session_id}")
def delete_chat_session(session_id: str, user_id: str, db: Session = Depends(get_db)):
    """
    Eliminar un chat específico.
    Si es el chat activo, se crea uno nuevo automáticamente.
    """
    # Verificar que el chat existe y pertenece al usuario
    session = db.query(ChatSession).filter(
        ChatSession.id == session_id,
        ChatSession.user_id == user_id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Chat no encontrado")
    
    was_active = session.is_active
    
    # Eliminar el chat (cascade eliminará mensajes también)
    db.delete(session)
    db.commit()
    
    # Si era el chat activo, crear uno nuevo
    new_session_id = None
    if was_active:
        new_session = ChatSession(
            user_id=user_id,
            search_state=[],
            is_active=True,
            title=None
        )
        db.add(new_session)
        db.commit()
        db.refresh(new_session)
        new_session_id = str(new_session.id)
    
    return {
        "deleted": True,
        "was_active": was_active,
        "new_session_id": new_session_id,
        "message": "Chat eliminado" + (" y nuevo creado" if was_active else "")
    }


@router.get("/chats/{session_id}/messages")
def get_chat_messages(session_id: str, user_id: str, db: Session = Depends(get_db)):
    """Obtener mensajes de un chat específico"""
    session = db.query(ChatSession).filter(
        ChatSession.id == session_id,
        ChatSession.user_id == user_id
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Chat no encontrado")
    
    messages_data = []
    for msg in session.messages:
        messages_data.append({
            "id": str(msg.id), # <--- ID NECESARIO PARA PERSISTENCIA
            "role": msg.role,
            "content": msg.content,
            "created_at": msg.created_at.isoformat(),
            "attachment": msg.attachment_data # <--- NUEVO
        })
    
    # Generar título si no existe
    title = session.title
    if not title:
        title = generate_chat_title(
            session.search_state or [],
            session.created_at,
            len(messages_data)
        )
    
    return {
        "session_id": str(session.id),
        "title": title,
        "search_state": session.search_state or [],
        "messages": messages_data,
        "is_current": session.is_active
    }


@router.get("/chats/current")
def get_current_chat(user_id: str, db: Session = Depends(get_db)):
    """Obtener el chat activo actual del usuario, o crear uno si no existe"""
    session = db.query(ChatSession).filter(
        ChatSession.user_id == user_id,
        ChatSession.is_active == True
    ).first()
    
    # Si no hay chat activo, crear uno nuevo
    if not session:
        session = ChatSession(
            user_id=user_id,
            search_state=[],
            is_active=True,
            title=None
        )
        db.add(session)
        db.commit()
        db.refresh(session)
    
    return {
        "session_id": str(session.id),
        "title": session.title or generate_chat_title(
            session.search_state or [],
            session.created_at,
            len(session.messages) if session.messages else 0
        ),
        "search_state": session.search_state or [],
        "message_count": len(session.messages) if session.messages else 0
    }


@router.get("/orders")
def get_user_orders(user_id: str, db: Session = Depends(get_db)):
    """Obtener historial de pedidos PAGADOS del usuario"""
    reservations = db.query(Reservation).filter(
        Reservation.user_id == user_id,
        Reservation.status.in_(["PAID", "COMPLETED", "CREDIT", "PENDING"])  # Incluye PENDING
    ).order_by(desc(Reservation.created_at)).limit(50).all()
    
    result = []
    for res in reservations:
        items = []
        for item in res.items:
            items.append({
                "product_name": item.product_name,
                "quantity": item.quantity,
                "unit_price": float(item.unit_price),
                "total_price": float(item.total_price)
            })
        
        result.append({
            "id": str(res.id),
            "bodega_name": res.bodega.name if res.bodega else "Bodega",
            "total_amount": float(res.total_amount),
            "status": res.status,
            "created_at": res.created_at.isoformat(),
            "items": items,
            "qr_data": decrypt_value(res.qr_code_data)  # 🔓 Desencriptar para mostrar
        })
    
    return result


@router.patch("/orders/{order_id}/cancel")
def cancel_order(order_id: str, user_id: str, db: Session = Depends(get_db)):
    """Cancelar un pedido pendiente"""
    reservation = db.query(Reservation).filter(
        Reservation.id == order_id,
        Reservation.user_id == user_id
    ).first()
    
    if not reservation:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")
        
    if reservation.status != "PENDING":
        raise HTTPException(status_code=400, detail="Solo se pueden cancelar pedidos pendientes")
        
    reservation.status = "CANCELLED"
    db.commit()
    
    return {"message": "Pedido cancelado exitosamente"}

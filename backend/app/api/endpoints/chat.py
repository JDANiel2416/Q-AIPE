from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.tables import ChatMessage
from uuid import UUID
from typing import Dict, Any

router = APIRouter()

@router.patch("/messages/{message_id}")
def update_message_attachment(
    message_id: str,
    attachment_update: Dict[str, Any] = Body(...),
    db: Session = Depends(get_db)
):
    """
    Actualiza el campo 'attachment_data' de un mensaje específico.
    Se usa para persistir estados de UI como 'is_reserved' o 'ticket_data'.
    Realiza un MERGE con los datos existentes.
    """
    try:
        msg_uuid = UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format")

    message = db.query(ChatMessage).filter(ChatMessage.id == msg_uuid).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    # Merge data
    current_data = message.attachment_data or {}
    # Actualizamos con los nuevos keys
    current_data.update(attachment_update)
    
    # Asignamos de nuevo para que SQLAlchemy detecte el cambio en JSONB
    message.attachment_data = dict(current_data)
    
    db.commit()
    db.refresh(message)
    
    return {"success": True, "attachment_data": message.attachment_data}

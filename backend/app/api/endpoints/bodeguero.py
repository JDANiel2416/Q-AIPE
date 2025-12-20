from fastapi import APIRouter, UploadFile, File, Depends, Form
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.services.gemini_service import gemini_client
from app.repositories.inventory_repo import InventoryRepository
import shutil
import os

router = APIRouter()

@router.post("/update_voice")
async def update_inventory_voice(
    bodega_id: str = Form(...), # El ID viene como texto en el form data
    audio: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Guardar audio temporalmente (Gemini necesita un archivo en disco)
    temp_filename = f"temp_{audio.filename}"
    with open(temp_filename, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    try:
        # 2. Enviar a Gemini (Service)
        # Gemini escucha el audio y nos devuelve JSON: {"action": "ADD", "items": [...]}
        intent = await gemini_client.process_bodeguero_audio(temp_filename)
        
        if "error" in intent:
            return {"success": False, "message": intent["error"]}

        # 3. Actualizar Base de Datos (Repository)
        updates_log = []
        items = intent.get("items", [])
        
        for item in items:
            prod_name = item.get("product_normalized")
            qty = item.get("quantity_to_add", 0)
            
            success, msg = InventoryRepository.update_stock(
                db, bodega_id, prod_name, qty
            )
            updates_log.append(msg)

        return {
            "success": True, 
            "message": "Stock actualizado correctamente",
            "details": updates_log,
            "raw_intent": intent
        }

    finally:
        # Limpieza: Borrar archivo temporal
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
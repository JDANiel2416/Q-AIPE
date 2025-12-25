from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.db.session import get_db
from app.models.tables import User
from app.services.reniec_service import reniec_client

router = APIRouter()

# --- MODELOS (Solo para este archivo) ---
class DniQuery(BaseModel):
    dni: str

class RegisterRequest(BaseModel):
    dni: str
    password: str
    phone: str
    role: str = "CLIENT" 

# --- RUTAS ---

@router.post("/consult_dni")
async def consult_dni(query: DniQuery, db: Session = Depends(get_db)):
    # 1. Validar si ya existe el usuario
    existing = db.query(User).filter(User.dni == query.dni).first()
    if existing:
        # Si ya existe, devolvemos el nombre censurado para que sepa que es él
        masked = reniec_client.obfuscate_name(existing.full_name)
        return {"success": True, "masked_name": masked, "exists": True, "message": "Usuario ya registrado"}

    # 2. Consultar Reniec
    reniec_data = await reniec_client.get_person_by_dni(query.dni)
    if not reniec_data:
        return {"success": False, "message": "DNI no encontrado"}

    # 3. Devolver nombre censurado
    masked = reniec_client.obfuscate_name(reniec_data["full_name"])
    return {"success": True, "masked_name": masked, "exists": False, "message": "¿Eres tú?"}

@router.post("/register")
async def register_user(req: RegisterRequest, db: Session = Depends(get_db)):
    # 1. Doble verificación de duplicados
    if db.query(User).filter(User.dni == req.dni).first():
        raise HTTPException(status_code=400, detail="DNI ya registrado")
    
    # 2. Obtener nombre real (No confiamos en el frontend)
    reniec_data = await reniec_client.get_person_by_dni(req.dni)
    if not reniec_data:
        raise HTTPException(status_code=400, detail="Error de identidad")

    # 3. Guardar en DB
    new_user = User(
        dni=req.dni,
        full_name=reniec_data["full_name"], # Guardamos el nombre COMPLETO
        password_hash=req.password,         
        phone_number=req.phone,
        role=req.role,
        is_verified=True
    )
    
    db.add(new_user)
    db.commit()
    
    return {"success": True, "message": "Bienvenido al barrio", "user_id": str(new_user.id)}
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.services.reniec_service import ReniecService
from app.models.tables import User
from pydantic import BaseModel

router = APIRouter()

class ConsultRequest(BaseModel):
    dni: str

class LoginRequest(BaseModel):
    dni: str
    password: str

class RegisterRequest(BaseModel):
    dni: str
    password: str
    phone: str
    role: str = "CLIENT"

@router.post("/consult_dni")
def consult_dni(req: ConsultRequest, db: Session = Depends(get_db)):
    # 1. ¿El usuario YA existe en nuestra BD?
    existing_user = db.query(User).filter(User.dni == req.dni).first()
    
    if existing_user:
        # ¡SI EXISTE! Avisamos al frontend para que cambie a modo Login
        return {
            "success": True,
            "masked_name": existing_user.full_name, # Ya tenemos el nombre real
            "exists": True, # <--- ESTO ES LA CLAVE
            "message": "Usuario ya registrado"
        }

    # 2. Si no existe, buscamos en RENIEC (Simulado o Real)
    # Aquí podrías usar tu servicio real de Reniec si lo tienes activado
    # Por ahora simulamos éxito para nuevos registros
    return {
        "success": True, 
        "masked_name": "VECINO NUEVO", 
        "exists": False, # <--- No existe, hay que registrarlo
        "message": "¿Eres tú?"
    }

@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.dni == req.dni).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # Validación simple (En producción usarías hash tipo bcrypt)
    if user.password_hash != req.password:
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
        
    return {
        "success": True, 
        "user_id": str(user.id),
        "name": user.full_name,
        "role": user.role
    }

@router.post("/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.dni == req.dni).first():
        raise HTTPException(status_code=400, detail="El DNI ya está registrado")

    new_user = User(
        dni=req.dni,
        full_name=f"Usuario {req.dni}", # O el nombre de Reniec si lo tuvieras
        password_hash=req.password,
        phone_number=req.phone,
        role=req.role,
        is_verified=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {"success": True, "user_id": str(new_user.id)}
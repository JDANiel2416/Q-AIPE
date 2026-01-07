from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.services.reniec_service import ReniecService # <--- Asegúrate que esto se importe bien
from app.models.tables import User
from pydantic import BaseModel

router = APIRouter()

# ... (Tus clases BaseModel ConsultRequest, LoginRequest, etc. siguen igual) ...
class ConsultRequest(BaseModel):
    dni: str

class LoginRequest(BaseModel):
    dni: str
    password: str

# Actualizado con los datos del bodeguero que añadimos antes
class RegisterRequest(BaseModel):
    dni: str
    password: str
    phone: str
    role: str = "CLIENT"
    bodega_name: str | None = None
    latitude: float | None = None
    longitude: float | None = None

# 👇👇👇 AQUÍ ESTÁ EL CAMBIO IMPORTANTE 👇👇👇
@router.post("/consult_dni")
async def consult_dni(req: ConsultRequest, db: Session = Depends(get_db)): # <--- Ahora es ASYNC
    # 1. ¿El usuario YA existe en nuestra BD?
    existing_user = db.query(User).filter(User.dni == req.dni).first()
    
    if existing_user:
        return {
            "success": True,
            "masked_name": existing_user.full_name,
            "exists": True,
            "message": "Usuario ya registrado"
        }

    # 2. Si no existe, buscamos en RENIEC
    # Usamos tu servicio real/simulado
    print(f"🔎 Consultando RENIEC para DNI: {req.dni}") # Log para depurar
    reniec_data = await ReniecService.get_person_by_dni(req.dni)
    
    if reniec_data:
        # ¡ÉXITO! Encontramos el nombre real
        masked_name = ReniecService.obfuscate_name(reniec_data.get("full_name"))
        return {
            "success": True, 
            "masked_name": masked_name, # <--- AQUÍ VA EL NOMBRE DE LA API
            "exists": False, 
            "message": f"Encontré a {masked_name}. ¿Eres tú?"
        }
    else:
        # Fallback si falla la API o no hay token
        return {
            "success": True, 
            "masked_name": "Vecino", 
            "exists": False, 
            "message": "No encontré tu nombre, pero igual regístrate."
        }

# ... (El resto de endpoints login y register siguen igual) ...
@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.dni == req.dni).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if user.password_hash != req.password:
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    return {"success": True, "user_id": str(user.id), "name": user.full_name, "role": user.role}

@router.post("/register")
async def register(req: RegisterRequest, db: Session = Depends(get_db)): # <--- 1. AHORA ES ASYNC
    # Validar si ya existe
    if db.query(User).filter(User.dni == req.dni).first():
        raise HTTPException(status_code=400, detail="El DNI ya está registrado")

    # 2. OBTENER NOMBRE REAL (Para guardarlo bien en la BD)
    # Hacemos la consulta interna de nuevo para asegurar que guardamos el nombre correcto
    reniec_data = await ReniecService.get_person_by_dni(req.dni)
    
    # Si Reniec responde, usamos el nombre. Si falla, usamos el fallback "Usuario DNI"
    real_name = reniec_data.get("full_name") if reniec_data else f"Usuario {req.dni}"

    new_user = User(
        dni=req.dni,
        full_name=real_name, # <--- 3. AQUÍ GUARDAMOS EL NOMBRE REAL
        password_hash=req.password,
        phone_number=req.phone,
        role=req.role,
        is_verified=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Lógica de Bodeguero (Igual que antes)
    if req.role == "BODEGUERO" and req.bodega_name:
         from app.models.tables import Bodega 
         new_bodega = Bodega(
            owner_id=new_user.id,
            name=req.bodega_name,
            latitude=req.latitude,
            longitude=req.longitude,
            manual_override="OPEN",
            rating=5.0
        )
         db.add(new_bodega)
         db.commit()

    return {
        "success": True, 
        "user_id": str(new_user.id),
        "role": new_user.role  # <--- ¡ESTO FALTABA!
    }

    if db.query(User).filter(User.dni == req.dni).first():
        raise HTTPException(status_code=400, detail="El DNI ya está registrado")

    # Si recibimos datos de reniec antes, podrías pasarlos aquí, 
    # pero por ahora usaremos "Usuario DNI" si no se envía el nombre.
    # (Para mejorarlo, deberíamos pedir el nombre en el frontend si Reniec falla)
    
    new_user = User(
        dni=req.dni,
        full_name=f"Usuario {req.dni}", 
        password_hash=req.password,
        phone_number=req.phone,
        role=req.role,
        is_verified=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Lógica de Bodeguero (Opcional, la que tenías antes)
    if req.role == "BODEGUERO" and req.bodega_name:
         from app.models.tables import Bodega # Import local para evitar ciclos
         new_bodega = Bodega(
            owner_id=new_user.id,
            name=req.bodega_name,
            latitude=req.latitude,
            longitude=req.longitude,
            manual_override="OPEN",
            rating=5.0
        )
         db.add(new_bodega)
         db.commit()

    return {"success": True, "user_id": str(new_user.id)}
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.services.reniec_service import ReniecService
from app.models.tables import User
from app.core.security import verify_password, get_password_hash, encrypt_value, get_search_hash
from pydantic import BaseModel

router = APIRouter()

# ... (Tus clases BaseModel ConsultRequest, LoginRequest, etc. siguen igual) ...
class ConsultRequest(BaseModel):
    dni: str
    first_name: str | None = None
    last_name: str | None = None

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
async def consult_dni(req: ConsultRequest, db: Session = Depends(get_db)):
    # 1. ¿El usuario YA existe en nuestra BD?
    existing_user = db.query(User).filter(User.dni == req.dni).first()
    
    if existing_user:
        masked = ReniecService.obfuscate_name(existing_user.full_name) # Usar nuevo formato estricto después
        return {
            "success": True,
            "masked_name": masked,
            "exists": True,
            "message": "Usuario ya registrado"
        }

    # 2. Si no existe, buscamos en RENIEC
    print(f"🔎 Consultando RENIEC para DNI: {req.dni}")
    reniec_data = await ReniecService.get_person_by_dni(req.dni)
    
    if reniec_data:
        full_name_db = reniec_data.get("full_name", "").upper()
        
        # 🟢 CORRECCIÓN: Si es la primera consulta (solo DNI), no hay nombres para validar.
        # Retornamos success=True para que el Frontend avance al paso de "Verificar Nombre".
        if not req.first_name or not req.last_name:
             return {
                "success": True, 
                "masked_name": "Usuario", 
                "exists": False, 
                "message": "DNI válido. Por favor verifica tu identidad."
            }

        # VALIDACIÓN DE NOMBRE (Case Insensitive)
        input_name = f"{req.first_name} {req.last_name}".strip().upper()
        
        # Estrategia simple: verificar si los tokens ingresados están en el nombre completo
        # Ej: Input "JUAN PEREZ" in "JUAN CARLOS PEREZ GOMEZ" -> True
        input_tokens = input_name.split()
        db_tokens = full_name_db.split()
        
        match_count = 0
        for token in input_tokens:
            if token in db_tokens:
                match_count += 1
        
        # Umbral: Al menos todos los tokens ingresados deben coincidir (o la mayoría)
        # Para ser estricto: deben estar todos.
        all_matched = all(token in db_tokens for token in input_tokens)
        
        if not all_matched:
             return {
                "success": False,
                "message": "El nombre ingresado no coincide con el DNI."
            }

        # ¡ÉXITO! Encontramos y validamos
        # MASKING ESTRICTO: Primeras 3 letras de cada palabra principal
        # Ej: "JUAN CARLOS PEREZ GOMEZ" -> "JUA... CAR... PER... GOM..."
        def strict_mask(text):
            parts = text.split()
            masked_parts = []
            for p in parts:
                if len(p) > 3:
                     masked_parts.append(p[:3] + "...")
                else:
                     masked_parts.append(p) # Nombres muy cortos se muestran
            return " ".join(masked_parts)

        masked_name = strict_mask(full_name_db)

        return {
            "success": True, 
            "masked_name": masked_name,
            "exists": False, 
            "message": f"Identidad verificada: {masked_name}"
        }
    else:
        # Fallback
        return {
            "success": False, 
            "message": "No se encontraron datos para este DNI."
        }

# ... (El resto de endpoints login y register siguen igual) ...
@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    # 1. Buscar usuario por DNI (DNI sigue siendo texto plano para búsqueda rápida)
    user = db.query(User).filter(User.dni == req.dni).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # 2. Verificar password con Bcrypt
    if not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
        
    return {"success": True, "user_id": str(user.id), "name": user.full_name, "role": user.role}


class RegisterFCMTokenRequest(BaseModel):
    user_id: str
    fcm_token: str


@router.post("/register-fcm-token")
def register_fcm_token(req: RegisterFCMTokenRequest, db: Session = Depends(get_db)):
    """Registra el token FCM de un usuario para recibir notificaciones push."""
    user = db.query(User).filter(User.id == req.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    user.fcm_token = encrypt_value(req.fcm_token)
    db.commit()
    
    print(f"✅ FCM Token registrado para usuario {user.full_name}: {req.fcm_token[:30]}...")
    return {"success": True, "message": "FCM token registrado correctamente"}


class UnregisterFCMTokenRequest(BaseModel):
    user_id: str


@router.post("/unregister-fcm-token")
def unregister_fcm_token(req: UnregisterFCMTokenRequest, db: Session = Depends(get_db)):
    """Elimina el token FCM de un usuario al cerrar sesión (evita notificaciones cruzadas)."""
    user = db.query(User).filter(User.id == req.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    old_token = user.fcm_token
    user.fcm_token = None  # Limpiar token
    db.commit()
    
    if old_token:
        print(f"🔓 FCM Token eliminado para usuario {user.full_name}")
    return {"success": True, "message": "FCM token eliminado correctamente"}


class ValidatePhoneRequest(BaseModel):
    phone: str


@router.post("/validate-phone")
def validate_phone(req: ValidatePhoneRequest, db: Session = Depends(get_db)):
    """Valida si un número de teléfono ya está registrado en la base de datos."""
    # Buscamos por el HASH del teléfono, no el texto plano (que está encriptado)
    phone_hash_to_check = get_search_hash(req.phone)
    existing_user = db.query(User).filter(User.phone_hash == phone_hash_to_check).first()
    
    if existing_user:
        return {
            "available": False,
            "message": "Este número ya está asociado a otra cuenta"
        }
    
    return {
        "available": True,
        "message": "Número disponible"
    }


@router.post("/register")
async def register(req: RegisterRequest, db: Session = Depends(get_db)): # <--- 1. AHORA ES ASYNC
    # Validar contraseña segura
    if len(req.password) < 6:
         raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 6 caracteres.")
    
    weak_patterns = ["123456", "654321", "000000", "password", "contraseña"]
    if req.password in weak_patterns:
         raise HTTPException(status_code=400, detail="Esa contraseña es muy común. Elige una más segura.")
         
    # Validar caracteres idénticos consecutivos (ej: 111111)
    if len(set(req.password)) == 1:
        raise HTTPException(status_code=400, detail="La contraseña no puede tener todos los caracteres iguales.")

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
        full_name=real_name,
        # SECURIZAR DATOS:
        password_hash=get_password_hash(req.password),
        phone_number=encrypt_value(req.phone),      # Guardar encriptado
        phone_hash=get_search_hash(req.phone),      # Guardar hash para buscar
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
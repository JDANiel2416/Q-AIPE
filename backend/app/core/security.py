import bcrypt
from cryptography.fernet import Fernet
import hashlib
from app.core.config import settings

# 1. Password Hashing (Bcrypt Direct)
# passlib tiene problemas con bcrypt > 4.0 en Windows (error 72 bytes),
# así que usamos la librería bcrypt directamente.

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica si la contraseña plana coincide con el hash."""
    # bcrypt.checkpw necesita bytes
    if not isinstance(plain_password, bytes):
        plain_password = plain_password.encode('utf-8')
    if not isinstance(hashed_password, bytes):
        hashed_password = hashed_password.encode('utf-8')
        
    return bcrypt.checkpw(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Genera un hash seguro de la contraseña."""
    if not isinstance(password, bytes):
        password = password.encode('utf-8')
    
    # Generar salt y hash
    hashed = bcrypt.hashpw(password, bcrypt.gensalt())
    return hashed.decode('utf-8')

# 2. Symmetric Encryption (Fernet)
# Asegura que la clave sea válida (url-safe base64 de 32 bytes)
# Si falla, genera una nueva para evitar crash (pero ojo: los datos previos no se podrán leer)
try:
    _fernet = Fernet(settings.ENCRYPTION_KEY)
except Exception as e:
    print(f"⚠️ Error cargando ENCRYPTION_KEY: {e}. Generando una temporal insegura.")
    _fernet = Fernet(Fernet.generate_key())

def encrypt_value(value: str) -> str:
    """Encripta un string para guardarlo en BD."""
    if not value:
        return None
    return _fernet.encrypt(value.encode()).decode()

def decrypt_value(token: str) -> str:
    """Desencripta un valor traído de la BD."""
    if not token:
        return None
    try:
        return _fernet.decrypt(token.encode()).decode()
    except Exception:
        return "[Error desencriptando]"

# 3. Deterministic Hashing for Search (SHA-256)
def get_search_hash(value: str) -> str:
    """
    Genera un hash determinista (SHA-256) para campos que necesitan ser buscables
    (como teléfono o email) pero que están encriptados.
    """
    if not value:
        return None
    return hashlib.sha256(value.encode()).hexdigest()

import sys
import os
from sqlalchemy import text

# Importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import User
from app.core.security import decrypt_value, _fernet, settings
from cryptography.fernet import Fernet

def debug_crypto():
    print("DEBUGGING CRYPTO")
    print("===================")
    
    # 1. Verificar Clave
    key = settings.ENCRYPTION_KEY
    print(f"Key Loaded: {key[:5]}...{key[-5:]}")
    
    # 2. Consultar BD
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.full_name.like("%gAAAA%")).first()
        if not user:
            # Intentar buscar por DNI de Don Lucho si no encontramos por patrón encriptado
            user = db.query(User).filter(User.dni == "11111111").first()
            
        if user:
            print(f"User Found: {user.dni}")
            print(f"Stored Full Name: {user.full_name}")
            
            # 3. Intentar Desencriptar
            try:
                decrypted = _fernet.decrypt(user.full_name.encode()).decode()
                print(f"Decrypted (Direct): {decrypted}")
            except Exception as e:
                print(f"Decryption Failed (Direct): {e}")

            # 4. Probar función wrapper
            wrapper_result = decrypt_value(user.full_name)
            print(f"Wrapper Result: {wrapper_result}")
            
            # 5. Prueba de sanidad
            test_str = "HOLA"
            encrypted_test = _fernet.encrypt(test_str.encode()).decode()
            print(f"Test Encrypt '{test_str}': {encrypted_test}")
            decrypted_test = _fernet.decrypt(encrypted_test.encode()).decode()
            print(f"Test Decrypt: {decrypted_test}")
            
        else:
            print("No user found to test.")
            
    except Exception as e:
        print(f"Error DB: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    debug_crypto()

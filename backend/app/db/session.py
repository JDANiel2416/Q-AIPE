from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# 1. Creamos el MOTOR (Engine) usando la URL que pusiste en .env
# Configuración de Connection Pool para manejar múltiples usuarios concurrentes
engine = create_engine(
    settings.DATABASE_URL,
    pool_size=10,           # Conexiones mínimas activas en el pool
    max_overflow=20,        # Conexiones extras permitidas bajo carga alta
    pool_timeout=30,        # Segundos de espera antes de timeout si no hay conexiones
    pool_recycle=1800,      # Reciclar conexiones cada 30 min (evita conexiones muertas)
    pool_pre_ping=True      # Verificar que la conexión esté activa antes de usarla
)

# 2. Creamos la FÁBRICA DE SESIONES
# Cada vez que un usuario pide algo, esta fábrica crea una sesión temporal
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 3. La Dependencia (Dependency)
# Esta función es vital para FastAPI. Se asegura de abrir la conexión 
# cuando llega una petición y CERRARLA cuando termina (aunque haya error).
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
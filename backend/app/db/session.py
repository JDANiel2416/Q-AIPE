from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# 1. Creamos el MOTOR (Engine) usando la URL que pusiste en .env
engine = create_engine(settings.DATABASE_URL)

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
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware  # <--- IMPORTANTE: Importar Middleware
from app.core.config import settings
from app.api.api import api_router
from app.db.base import Base
from app.db.session import engine

# Crear tablas automáticamente al iniciar (Solo para MVP)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Servir archivos estáticos (imágenes)
from fastapi.staticfiles import StaticFiles
import os

static_dir = "static"
if not os.path.exists(static_dir):
    os.makedirs(static_dir)

app.mount("/static", StaticFiles(directory=static_dir), name="static")

# --- CONFIGURACIÓN DE CORS (SOLUCIÓN AL ERROR) ---
# Esto permite que el Frontend (Flutter Web/Mobile/Desktop) envíe peticiones al Backend
origins = [
    "*", # En producción se cambia por la URL real, pero para desarrollo usamos "*" (todos)
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], # Permite todos los métodos: GET, POST, OPTIONS, PUT, DELETE
    allow_headers=["*"], # Permite todos los headers
)
# ------------------------------------------------

# Conectar rutas
app.include_router(api_router, prefix=settings.API_V1_STR)

# Notifications Router
from app.api.endpoints import notifications
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["notifications"])

# Client Router (Mis Chats, Historial, Perfil)
from app.api.endpoints import client
app.include_router(client.router, prefix="/api/v1/client", tags=["client"])

@app.get("/")
def root():
    return {"message": "🚀 API Bodega Inteligente está corriendo con Gemini 3"} 
 
 
 
 

from fastapi import APIRouter
from app.api.endpoints import search, bodeguero, auth

api_router = APIRouter()

# Incluimos las rutas con prefijos
api_router.include_router(search.router, prefix="/search", tags=["Búsqueda (Vecinos)"])
api_router.include_router(bodeguero.router, prefix="/bodega", tags=["Gestión (Bodegueros)"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(bodeguero.router, prefix="/bodeguero", tags=["bodeguero"])
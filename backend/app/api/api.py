from fastapi import APIRouter
from app.api.endpoints import search, bodeguero, auth, reservations

api_router = APIRouter()

# Incluimos las rutas con prefijos
api_router.include_router(search.router, prefix="/search", tags=["search"])
api_router.include_router(bodeguero.router, prefix="/bodeguero", tags=["bodeguero"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(reservations.router, prefix="/reservations", tags=["reservations"])
api_router.include_router(bodeguero.router, prefix="/bodeguero", tags=["bodeguero"])
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from uuid import UUID

# --- 1. SCHEMAS DE ENTRADA (REQUESTS) ---
# Lo que Flutter le envía a Python

class SearchRequest(BaseModel):
    query: str              # Ej: "Una gorda y arroz"
    user_lat: float         # Ej: -8.0783
    user_lon: float         # Ej: -79.1180
    user_id: Optional[UUID] = None # NUEVO: Para identificar al usuario y su historial
    session_id: Optional[UUID] = None # NUEVO: Para identificar el chat específico
    conversation_history: List[Dict[str, str]] = []
    transcription: Optional[str] = None # NUEVO: Para devolverlo en la respuesta si viene de voz

class BodegaStatusUpdate(BaseModel):
    manual_override: Optional[str] = None # 'OPEN', 'CLOSED' o None (null)

# --- 2. SCHEMAS INTERMEDIOS (Para reusar) ---

class ProductItem(BaseModel):
    product_id: int
    name: str
    price: float
    stock: float
    unit: str
    
    # Detalle del producto
    attributes: Optional[Dict[str, Any]] = {} 
    
    # NUEVO: La cantidad que pidió el usuario (Ej: 2, 3)
    requested_quantity: int = 1 
    
    # NUEVO: Datos visuales para cards
    image_url: Optional[str] = None
    category: Optional[str] = None

    class Config:
        from_attributes = True

class ProductCreateRequest(BaseModel):
    name: str               # "Agua de Mesa"
    category: str           # "Bebidas"
    subcategory_id: Optional[int] = None # NUEVO
    master_product_id: Optional[int] = None # NUEVO
    price: float            # 2.50
    stock: int              # 50
    attributes: Dict[str, Any] # {"marca": "San Luis", "capacidad": "1L"}

# --- 3. SCHEMAS DE SALIDA (RESPONSES) ---
# Lo que Python le responde a Flutter

class BodegaSearchResult(BaseModel):
    bodega_id: UUID
    name: str
    distance_meters: int
    latitude: float
    longitude: float
    is_open: bool
    completeness_score: float
    total_price: float
    found_items: List[ProductItem]
    missing_items: List[str]

class SmartSearchResponse(BaseModel):
    message: str
    results: List[BodegaSearchResult]
    session_id: Optional[UUID] = None
    message_id: Optional[UUID] = None # NUEVO: Para poder actualizar el mensaje con la reserva
    is_order_summary: bool = False
    transcription: Optional[str] = None # NUEVO

class VoiceUpdateResponse(BaseModel):
    message: str
    detected_intent: dict
    success: bool

class InventoryListResponse(BaseModel):
    bodega_name: str
    items: List[ProductItem]
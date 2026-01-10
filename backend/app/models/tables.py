from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, Numeric, TIME, TIMESTAMP, text
from sqlalchemy.dialects.postgresql import UUID, ARRAY, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base
import uuid

# 1. USUARIOS (Ahora blindada 🛡️)
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Identidad Real
    dni = Column(String(8), unique=True, nullable=True, index=True) # DNI es clave
    full_name = Column(String, nullable=True)
    
    # Credenciales & Contacto
    phone_number = Column(String, unique=True, nullable=True)
    email = Column(String, unique=True, nullable=True)
    password_hash = Column(String, nullable=True) # Nunca guardamos texto plano
    
    # Roles y Estados
    role = Column(String, default="CLIENT") # 'CLIENT', 'BODEGUERO', 'ADMIN'
    is_active = Column(Boolean, default=True)   # Para bloquear usuarios maliciosos
    is_verified = Column(Boolean, default=False) # ¿Ya validó su DNI con Reniec?

    # Auditoría (Opcional pero recomendado)
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relaciones
    bodegas = relationship("Bodega", back_populates="owner")


# 2. BODEGAS (Sin cambios mayores, solo asegurando tipos)
class Bodega(Base):
    __tablename__ = "bodegas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    
    name = Column(String, nullable=False)
    address = Column(String, nullable=True)
    photo_url = Column(String, nullable=True) # Foto de fachada
    
    # Ubicación REAL (GPS)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    
    # Estado: 'OPEN', 'CLOSED', o NULL (Auto)
    manual_override = Column(String, nullable=True) 
    rating = Column(Numeric(2, 1), default=5.0)

    # Relaciones
    owner = relationship("User", back_populates="bodegas")
    schedules = relationship("BodegaSchedule", back_populates="bodega")
    inventory = relationship("StoreInventory", back_populates="bodega")


# 3. HORARIOS
class BodegaSchedule(Base):
    __tablename__ = "bodega_schedules"

    id = Column(Integer, primary_key=True, index=True)
    bodega_id = Column(UUID(as_uuid=True), ForeignKey("bodegas.id"))
    day_of_week = Column(Integer) # 0=Lunes, 6=Domingo
    open_time = Column(TIME, nullable=False)
    close_time = Column(TIME, nullable=False)

    bodega = relationship("Bodega", back_populates="schedules")


# 4. MEMORIA DE CHAT (HISTORIAL)
class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Puede ser NULL si es un usuario "invitado" o temporal, pero idealmente linkeado
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    search_state = Column(JSONB, default=[]) # Almacena la intención actual del usuario
    created_at = Column(TIMESTAMP, server_default=text("now()"))
    updated_at = Column(TIMESTAMP, server_default=text("now()"), onupdate=text("now()"))

    # Relaciones
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan")
    user = relationship("User")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("chat_sessions.id"), nullable=False)
    
    role = Column(String, nullable=False) # 'user' o 'assistant'
    content = Column(String, nullable=False) # El texto del mensaje
    
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relaciones
    session = relationship("ChatSession", back_populates="messages")


# 4. PRODUCTOS MAESTROS (Catálogo Global)
class MasterProduct(Base):
    __tablename__ = "master_products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(String)
    synonyms = Column(ARRAY(String)) # ["Gaseosa", "Refresco", "Soda"]
    image_url = Column(String)
    default_unit = Column(String) # "UND", "KG", "LT"
    # NUEVO CAMPO: Aquí se guardará {"marca": "Cielo", "gas": false}
    attributes = Column(JSONB, default={})


# 5. INVENTARIO
class StoreInventory(Base):
    __tablename__ = "store_inventory"

    bodega_id = Column(UUID(as_uuid=True), ForeignKey("bodegas.id"), primary_key=True)
    product_id = Column(Integer, ForeignKey("master_products.id"), primary_key=True)
    
    price = Column(Numeric(10, 2), nullable=False)
    stock_quantity = Column(Numeric(10, 2), default=0)
    is_available = Column(Boolean, default=True)

    bodega = relationship("Bodega", back_populates="inventory")
    product = relationship("MasterProduct")


# 6. RESERVAS
class Reservation(Base):
    __tablename__ = "reservations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    bodega_id = Column(UUID(as_uuid=True), ForeignKey("bodegas.id"), nullable=False)
    
    total_amount = Column(Numeric(10, 2), nullable=False)
    status = Column(String, default="PENDING") # PENDING, CONFIRMED, COMPLETED, CANCELLED
    qr_code_data = Column(String, nullable=True) # Data para generar el QR
    
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relaciones
    items = relationship("ReservationItem", back_populates="reservation", cascade="all, delete-orphan")
    user = relationship("User")
    bodega = relationship("Bodega")

class ReservationItem(Base):
    __tablename__ = "reservation_items"

    id = Column(Integer, primary_key=True, index=True)
    reservation_id = Column(UUID(as_uuid=True), ForeignKey("reservations.id"), nullable=False)
    
    product_name = Column(String, nullable=False) # Guardamos el nombre snapshot
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    total_price = Column(Numeric(10, 2), nullable=False)

    reservation = relationship("Reservation", back_populates="items")
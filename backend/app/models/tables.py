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
    # Credenciales & Contacto
    # DATOS ENCRIPTADOS (No buscables directamente)
    phone_number = Column(String, nullable=True) # Encriptado
    email = Column(String, nullable=True)        # Encriptado
    
    # DATOS CONFIDENCIALES PARA BUSQUEDA (Hash determinista)
    phone_hash = Column(String, unique=True, nullable=True, index=True) 
    email_hash = Column(String, unique=True, nullable=True, index=True)

    password_hash = Column(String, nullable=True) # Bcrypt hash (nunca texto plano)
    
    # Roles y Estados
    role = Column(String, default="CLIENT") # 'CLIENT', 'BODEGUERO', 'ADMIN'
    is_active = Column(Boolean, default=True)   # Para bloquear usuarios maliciosos
    is_verified = Column(Boolean, default=False) # ¿Ya validó su DNI con Reniec?
    
    # Push Notifications
    fcm_token = Column(String, nullable=True)  # Token de Firebase Cloud Messaging

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
    
    # Configuración de Delivery
    has_delivery = Column(Boolean, default=False)
    delivery_fee = Column(Numeric(10, 2), default=3.00)  # S/
    delivery_radius_km = Column(Numeric(4, 2), default=2.0)  # km

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
    
    # NUEVO: Título descriptivo del chat (ej: "Arroz y Coca Cola")
    title = Column(String, nullable=True)
    # NUEVO: Indica si es la sesión activa actual
    is_active = Column(Boolean, default=True)
    
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
    
    # NUEVO: Datos adjuntos (ej: resultados de búsqueda, productos recomendados)
    attachment_data = Column(JSONB, nullable=True)
    
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relaciones
    session = relationship("ChatSession", back_populates="messages")


# 3.5. CATEGORIAS (NUEVO)
class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    # Icono opcional para el frontend (ej: "local_drink_outlined")
    icon_name = Column(String, nullable=True)
    
    # Relaciones
    subcategories = relationship("SubCategory", back_populates="category", cascade="all, delete-orphan")

class SubCategory(Base):
    __tablename__ = "subcategories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)
    
    # Relaciones
    category = relationship("Category", back_populates="subcategories")

# 4. PRODUCTOS MAESTROS (Catálogo Global)
class MasterProduct(Base):
    __tablename__ = "master_products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    
    # Mantenemos 'category' string por seguridad durante la migración, pero añadimos el FK
    category = Column(String) 
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True) # Nullable al inicio
    subcategory_id = Column(Integer, ForeignKey("subcategories.id"), nullable=True) # NUEVO: FK Subcategoría
    
    synonyms = Column(ARRAY(String)) # ["Gaseosa", "Refresco", "Soda"]
    image_url = Column(String)
    default_unit = Column(String) # "UND", "KG", "LT"
    # NUEVO CAMPO: Aquí se guardará {"marca": "Cielo", "gas": false}
    attributes = Column(JSONB, default={})

    # Relaciones
    category_obj = relationship("Category")
    subcategory_obj = relationship("SubCategory")


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
    
    # Campos de Delivery
    delivery_type = Column(String, default="PICKUP")  # PICKUP | DELIVERY
    delivery_address_text = Column(String, nullable=True)  # "Jr. Los Pinos 123"
    delivery_coords_encrypted = Column(String, nullable=True)  # Coords encriptadas
    delivery_coords_expires_at = Column(TIMESTAMP, nullable=True)
    delivery_fee = Column(Numeric(10, 2), default=0)
    
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


# 7. NOTIFICACIONES (NUEVO)
class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False) # Bodeguero o Cliente
    
    title = Column(String, nullable=False)
    message = Column(String, nullable=False)
    type = Column(String, default="INFO") # INFO, WARNING, STOCK_ALERT, NEW_ORDER
    is_read = Column(Boolean, default=False)
    
    # Optional: product_id for STOCK_ALERT notifications
    product_id = Column(Integer, nullable=True)
    
    created_at = Column(TIMESTAMP, server_default=text("now()"))

    # Relaciones
    user = relationship("User")

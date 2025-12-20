from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, Numeric, TIME, TIMESTAMP, text
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship
from app.db.base import Base

# 1. USUARIOS
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    phone_number = Column(String, unique=True, nullable=False)
    full_name = Column(String)
    role = Column(String, nullable=False) # 'CLIENT', 'BODEGUERO', 'ADMIN'
    
    # Relaciones (Para navegar desde el código)
    bodegas = relationship("Bodega", back_populates="owner")

# 2. BODEGAS
class Bodega(Base):
    __tablename__ = "bodegas"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    name = Column(String, nullable=False)
    address = Column(String)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    
    # El famoso switch de 3 estados: 'OPEN', 'CLOSED', NULL
    manual_override = Column(String, nullable=True) 
    rating = Column(Numeric(2, 1), default=5.0)

    # Relaciones
    owner = relationship("User", back_populates="bodegas")
    schedules = relationship("BodegaSchedule", back_populates="bodega")
    inventory = relationship("StoreInventory", back_populates="bodega")

# 3. HORARIOS (Schedules)
class BodegaSchedule(Base):
    __tablename__ = "bodega_schedules"

    id = Column(Integer, primary_key=True, index=True)
    bodega_id = Column(UUID(as_uuid=True), ForeignKey("bodegas.id"))
    day_of_week = Column(Integer) # 0-6
    open_time = Column(TIME, nullable=False)
    close_time = Column(TIME, nullable=False)

    bodega = relationship("Bodega", back_populates="schedules")

# 4. PRODUCTOS MAESTROS (Catálogo Global)
class MasterProduct(Base):
    __tablename__ = "master_products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(String)
    
    # ¡Aquí está la magia de Gemini! Un array de textos.
    synonyms = Column(ARRAY(String)) 
    
    image_url = Column(String)
    default_unit = Column(String)

# 5. INVENTARIO (Relación Muchos-a-Muchos con datos extra)
class StoreInventory(Base):
    __tablename__ = "store_inventory"

    bodega_id = Column(UUID(as_uuid=True), ForeignKey("bodegas.id"), primary_key=True)
    product_id = Column(Integer, ForeignKey("master_products.id"), primary_key=True)
    
    price = Column(Numeric(10, 2), nullable=False)
    stock_quantity = Column(Numeric(10, 2), nullable=False)
    is_available = Column(Boolean, default=True)

    bodega = relationship("Bodega", back_populates="inventory")
    product = relationship("MasterProduct")
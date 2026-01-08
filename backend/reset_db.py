import sys
import os
from sqlalchemy import text # <--- Necesitamos esto para SQL crudo

# Ajuste para importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal, engine
from app.models.tables import Base, User, Bodega, MasterProduct, StoreInventory

def reset_database():
    print("💥 INICIANDO LIMPIEZA NUCLEAR...")
    
    # 1. FORZAR BORRADO DE TABLAS VIEJAS (Con SQL directo)
    # Esto elimina las tablas "fantasma" que Python no conoce pero PostgreSQL sí.
    with engine.connect() as connection:
        print("   - Eliminando tablas conflictivas...")
        connection.execute(text("DROP TABLE IF EXISTS chat_messages CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS chat_sessions CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS reservation_items CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS reservations CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS store_inventory CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS master_products CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS bodegas CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS users CASCADE;"))
        connection.commit()

    # 2. BORRAR CUALQUIER OTRA COSA QUE QUEDE
    print("   - Limpiando metadatos restantes...")
    Base.metadata.drop_all(bind=engine)

    # 3. CREAR TABLAS LIMPIAS
    print("🏗️  Creando tablas nuevas desde cero...")
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    
    try:
        print("🌱 Sembrando datos frescos...")

        # --- USUARIOS ---
        don_lucho = User(
            dni="11111111", full_name="LUIS RAMIREZ", password_hash="123", 
            phone_number="999", role="BODEGUERO", is_verified=True
        )
        tio_pepe = User(
            dni="22222222", full_name="JOSE TORRES", password_hash="123", 
            phone_number="888", role="BODEGUERO", is_verified=True
        )
        db.add_all([don_lucho, tio_pepe])
        db.commit()

        # --- BODEGAS ---
        bodega_lucho = Bodega(
            owner_id=don_lucho.id,
            name="Bodega Don Lucho",
            address="Av. La Rivera 123",
            latitude=-8.083267411952374, 
            longitude=-79.08689281105985,
            manual_override="OPEN", rating=4.8
        )
        bodega_pepe = Bodega(
            owner_id=tio_pepe.id,
            name="Bodega El Tío Pepe",
            address="Calle Los Olivos 456",
            latitude=-8.082630380806767, 
            longitude=-79.08790687508669,
            manual_override="OPEN", rating=4.5
        )
        db.add_all([bodega_lucho, bodega_pepe])
        db.commit()

        # --- PRODUCTOS ---
        p1 = MasterProduct(name="Arroz Costeño Graneadito", category="Abarrotes", synonyms=["arroz", "kilo de arroz"], default_unit="kg")
        p2 = MasterProduct(name="Cerveza Pilsen Callao 630ml", category="Licores", synonyms=["chela", "birra", "pilsen"], default_unit="botella")
        p3 = MasterProduct(name="Coca Cola 1.5L", category="Bebidas", synonyms=["gaseosa", "coca"], default_unit="botella")
        p4 = MasterProduct(name="Inca Kola 3L", category="Bebidas", synonyms=["gaseosa", "inka"], default_unit="botella")
        p5 = MasterProduct(name="Inca Kola 2L", category="Bebidas", synonyms=["gaseosa", "inka"], default_unit="botella")
        p6 = MasterProduct(name="Inca Kola 1.5L", category="Bebidas", synonyms=["gaseosa", "inka"], default_unit="botella")
        p7 = MasterProduct(name="Inca Kola 500ml", category="Bebidas", synonyms=["gaseosa", "inka", "personal"], default_unit="botella")

        db.add_all([p1, p2, p3, p4, p5, p6, p7])
        db.commit()

        # --- INVENTARIO ---
        inv = [
            StoreInventory(bodega_id=bodega_lucho.id, product_id=p1.id, price=4.50, stock_quantity=20),
            StoreInventory(bodega_id=bodega_lucho.id, product_id=p3.id, price=7.50, stock_quantity=15),
            StoreInventory(bodega_id=bodega_lucho.id, product_id=p5.id, price=9.00, stock_quantity=10, is_available=True), # Inca 2L (SÍ HAY)
            StoreInventory(bodega_id=bodega_lucho.id, product_id=p6.id, price=6.00, stock_quantity=24, is_available=True), # Inca 1.5L (SÍ HAY)
            # Inca 3L (p4) NO AGREGAMOS para simular que no hay
            
            StoreInventory(bodega_id=bodega_pepe.id, product_id=p2.id, price=8.00, stock_quantity=50), 
            StoreInventory(bodega_id=bodega_pepe.id, product_id=p1.id, price=4.40, stock_quantity=10)
        ]
        
        db.add_all(inv)
        db.commit()
        print("✅ ¡EXITO TOTAL! Base de datos reiniciada y limpia.")

    except Exception as e:
        print(f"❌ Error sembrando datos: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    reset_database()
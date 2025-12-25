import sys
import os

# Truco para que Python encuentre la carpeta 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import User, Bodega, MasterProduct, StoreInventory

db = SessionLocal()

def seed_db():
    print("🌱 Sembrando datos en el barrio...")

    # 1. CREAR BODEGUEROS (Usuarios)
    # Don Lucho
    don_lucho = User(
        dni="11111111",
        full_name="LUIS ALBERTO RAMIREZ",
        password_hash="secreto", # En el futuro esto irá encriptado
        phone_number="999111222",
        role="BODEGUERO",
        is_verified=True
    )
    
    # Tío Pepe
    tio_pepe = User(
        dni="22222222",
        full_name="JOSE MIGUEL TORRES",
        password_hash="secreto",
        phone_number="999333444",
        role="BODEGUERO",
        is_verified=True
    )
    
    db.add(don_lucho)
    db.add(tio_pepe)
    db.commit() # Guardamos para que generen ID
    
    print("✅ Don Lucho y Tío Pepe creados.")

    # 2. CREAR LAS BODEGAS (Con ubicación real en Huanchaco)
    bodega_lucho = Bodega(
        owner_id=don_lucho.id,
        name="Bodega Don Lucho",
        address="Av. La Rivera 123",
        latitude=-8.0783,   # Coordenada cerca al muelle
        longitude=-79.1180,
        manual_override="OPEN",
        rating=4.8
    )

    bodega_pepe = Bodega(
        owner_id=tio_pepe.id,
        name="Bodega El Tío Pepe",
        address="Calle Los Olivos 456",
        latitude=-8.0765,   # Un poco más al norte
        longitude=-79.1195,
        manual_override="OPEN",
        rating=4.5
    )

    db.add(bodega_lucho)
    db.add(bodega_pepe)
    db.commit()
    
    print("✅ Bodegas abiertas en el mapa.")

    # 3. CREAR PRODUCTOS MAESTROS (Catálogo Global)
    pilsen = MasterProduct(name="Cerveza Pilsen Callao 630ml", category="Licores", synonyms=["chela", "birra", "pilsen"], default_unit="botella")
    coca = MasterProduct(name="Coca Cola 1.5L", category="Bebidas", synonyms=["gaseosa", "coca", "cocacola"], default_unit="botella")
    arroz = MasterProduct(name="Arroz Costeño Graneadito", category="Abarrotes", synonyms=["arroz", "kilo de arroz"], default_unit="kg")
    
    db.add_all([pilsen, coca, arroz])
    db.commit()

    # 4. LLENAR STOCK (Inventario)
    # Don Lucho tiene todo
    inv1 = StoreInventory(bodega_id=bodega_lucho.id, product_id=pilsen.id, price=8.50, stock_quantity=24)
    inv2 = StoreInventory(bodega_id=bodega_lucho.id, product_id=coca.id, price=7.00, stock_quantity=10)
    
    # Tío Pepe tiene chela más barata pero no tiene arroz
    inv3 = StoreInventory(bodega_id=bodega_pepe.id, product_id=pilsen.id, price=8.00, stock_quantity=50)
    inv4 = StoreInventory(bodega_id=bodega_pepe.id, product_id=arroz.id, price=4.50, stock_quantity=20)

    db.add_all([inv1, inv2, inv3, inv4])
    db.commit()

    print("✅ Inventario cargado.")
    print("🚀 ¡Todo listo! Ya puedes buscar chelas.")

if __name__ == "__main__":
    try:
        seed_db()
    except Exception as e:
        print(f"Error sembrando: {e}")
        db.rollback()
    finally:
        db.close()
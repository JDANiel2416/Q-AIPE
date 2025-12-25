import sys
import os

# Ajuste de ruta para que encuentre la carpeta 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import MasterProduct, Bodega, StoreInventory

db = SessionLocal()

def diagnostico():
    print("📋 --- DIAGNÓSTICO DE BASE DE DATOS ---")
    
    # 1. VERIFICAR BODEGAS
    bodegas = db.query(Bodega).all()
    print(f"\n🏪 BODEGAS ENCONTRADAS: {len(bodegas)}")
    for b in bodegas:
        print(f"   - ID: {b.id} | Nombre: {b.name} | Estado: {b.manual_override}")
        print(f"     📍 Coordenadas: {b.latitude}, {b.longitude}")

    # 2. VERIFICAR PRODUCTOS
    productos = db.query(MasterProduct).all()
    print(f"\n📦 PRODUCTOS MAESTROS: {len(productos)}")
    for p in productos:
        print(f"   - ID: {p.id} | Nombre: '{p.name}' | Sinónimos: {p.synonyms}")

    # 3. VERIFICAR INVENTARIO (La relación)
    stock = db.query(StoreInventory).all()
    print(f"\n📊 STOCK DISPONIBLE: {len(stock)}")
    for s in stock:
        # Buscamos nombres para mostrar claro
        prod_name = db.query(MasterProduct.name).filter(MasterProduct.id == s.product_id).scalar()
        bodega_name = db.query(Bodega.name).filter(Bodega.id == s.bodega_id).scalar()
        print(f"   - {bodega_name} tiene: {prod_name} (Precio: S/{s.price})")

    # 4. PRUEBA DE BÚSQUEDA "ARROZ" (Simulando lo que falla)
    print("\n🕵️ PRUEBA DE BÚSQUEDA 'Arroz':")
    term = "%Arroz%"
    found = db.query(MasterProduct).filter(MasterProduct.name.ilike(term)).all()
    print(f"   -> Buscando '%Arroz%' en nombres: Encontrados {len(found)}")
    for f in found:
        print(f"      - Coincidencia: {f.name}")

if __name__ == "__main__":
    try:
        diagnostico()
    except Exception as e:
        print(f"❌ Error leyendo la BD: {e}")
    finally:
        db.close()
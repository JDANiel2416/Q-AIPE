import sys
import os
from sqlalchemy import text # <--- Necesitamos esto para SQL crudo

# Ajuste para importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal, engine
from app.models.tables import Base, User, Bodega, MasterProduct, StoreInventory, Category, SubCategory
from app.core.security import get_password_hash, encrypt_value, get_search_hash

def migrate_database():
    """
    Ejecutar migraciones (agregar columnas nuevas) SIN borrar datos existentes.
    Usar cuando solo quieres actualizar la estructura de tablas.
    """
    print("🔄 EJECUTANDO MIGRACIONES...")
    
    with engine.connect() as connection:
        # --- USUARIOS ---
        print("   - Migrando tabla 'users'...")
        try:
            connection.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR"))
            # Nuevas columnas de seguridad
            connection.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_hash VARCHAR"))
            connection.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS email_hash VARCHAR"))
            # Nota: En un entorno real, habría que migrar los datos existentes de phone -> phone_hash y encriptar phone.
            
            print("     ✅ Columnas 'fcm_token', 'phone_hash', 'email_hash' verificadas")
        except Exception as e:
            print(f"     ⚠️ Error migrando users: {e}")
        
        # --- RESTO DE MIGRACIONES (Igual que antes) ---
        # ...

        # --- CHAT SESSIONS ---
        print("   - Migrando tabla 'chat_sessions'...")
        try:
            connection.execute(text("ALTER TABLE chat_sessions ADD COLUMN IF NOT EXISTS title VARCHAR"))
            print("     ✅ Columna 'title' verificada")
        except Exception as e:
            print(f"     ⚠️ title: {e}")
        
        try:
            connection.execute(text("ALTER TABLE chat_sessions ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE"))
            print("     ✅ Columna 'is_active' verificada")
        except Exception as e:
            print(f"     ⚠️ is_active: {e}")
        
        # 3. Campos nuevos para chat mejorado (Persistencia de tarjetas)
        print("   - Migrando tabla 'chat_messages'...")
        try:
            connection.execute(text("ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS attachment_data JSONB"))
            print("     ✅ Columna 'attachment_data' verificada")
        except Exception as e:
            print(f"     ⚠️ attachment_data: {e}")
        
        # 4. Campos nuevos para Categorías
        print("   - Migrando tabla 'categories'...")
        try:
            connection.execute(text("ALTER TABLE categories ADD COLUMN IF NOT EXISTS icon_name VARCHAR"))
            print("     ✅ Columna 'icon_name' verificada")
        except Exception as e:
            print(f"     ⚠️ icon_name: {e}")

        # 5. FK category_id en MasterProduct
        print("   - Migrando tabla 'master_products'...")
        try:
            connection.execute(text("ALTER TABLE master_products ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES categories(id)"))
            print("     ✅ Columna 'category_id' verificada")
        except Exception as e:
            print(f"     ⚠️ category_id: {e}")
        
        connection.commit()
    
    print("🎉 MIGRACIONES COMPLETADAS")

def reset_database():
    print("💥 INICIANDO LIMPIEZA NUCLEAR...")
    
    # 1. FORZAR BORRADO DE TABLAS VIEJAS (Con SQL directo) (Igual que antes)
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
        connection.execute(text("DROP TABLE IF EXISTS categories CASCADE;"))
        connection.execute(text("DROP TABLE IF EXISTS subcategories CASCADE;")) # Faltaba subcategories
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

        # --- CATEGORIAS Y SUBCATEGORIAS ---
        # (Código de categorías se mantiene igual)...
        print("   - Creando categorías...")
        categories_data = [
            {"name": "Bebidas", "icon": "local_drink_outlined"},
            {"name": "Abarrotes", "icon": "shopping_basket_outlined"},
            {"name": "Limpieza", "icon": "cleaning_services_outlined"},
            {"name": "Cuidado Personal", "icon": "wash_outlined"},
            {"name": "Otros", "icon": "category_outlined"},
        ]
        
        cat_objects = {}
        for c in categories_data:
            cat_obj = Category(name=c["name"], icon_name=c["icon"])
            db.add(cat_obj)
            cat_objects[c["name"]] = cat_obj
        
        db.flush() # <--- IMPORTANTE: Generar IDs antes de usarlos en subcategorías
        
        print("   - Creando subcategorías...")
        seed_subcats = {
            "Bebidas": ["Gaseosas", "Agua", "Cervezas", "Energizantes", "Jugos", "Licores", "Vinos"],
            "Abarrotes": ["Arroz", "Azúcar", "Aceites", "Fideos", "Conservas", "Menestras", "Snacks", "Golosinas", "Panadería", "Embutidos", "Verduras", "Frutas", "Condimentos"],
            "Limpieza": ["Detergentes", "Jabones", "Desinfectantes", "Papel Higiénico"],
            "Cuidado Personal": ["Shampoo", "Desodorante", "Pasta Dental", "Farmacia", "Cremas"],
            "Otros": ["Mascotas", "Hogar", "Útiles Escolares", "Tecnología"]
        }
        
        subcat_objects = {}
        for p_name, subs in seed_subcats.items():
            if p_name in cat_objects:
                parent_id = cat_objects[p_name].id
                for s_name in subs:
                    sub = SubCategory(name=s_name, category_id=parent_id)
                    db.add(sub)
                    subcat_objects[s_name] = sub

        db.commit()

        # --- USUARIOS (SECURIZADOS) ---
        print("   - Creando usuarios con seguridad...")
        
        # Don Lucho
        lucho_phone = "999"
        don_lucho = User(
            dni="11111111", 
            full_name=encrypt_value("LUIS RAMIREZ"), # 🔐 Encrypting full_name
            password_hash=get_password_hash("123"),  # <-- Hash contraseña
            phone_number=encrypt_value(lucho_phone), # <-- Encriptar teléfono
            phone_hash=get_search_hash(lucho_phone), # <-- Hash teléfono para búsqueda
            role="BODEGUERO", 
            is_verified=True
        )
        
        # Tio Pepe
        pepe_phone = "888"
        tio_pepe = User(
            dni="22222222", 
            full_name=encrypt_value("JOSE TORRES"), # 🔐 Encrypting full_name
            password_hash=get_password_hash("123"), 
            phone_number=encrypt_value(pepe_phone),
            phone_hash=get_search_hash(pepe_phone),
            role="BODEGUERO", 
            is_verified=True
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
        # Usamos el mapa cat_objects y subcat_objects para obtener los IDs
        
        # Helper para simplificar creación
        def create_prod(name, cat_name, subcat_name, synonyms, unit="un"):
            return MasterProduct(
                name=name, 
                category=cat_name, 
                category_id=cat_objects[cat_name].id,
                subcategory_id=subcat_objects[subcat_name].id if subcat_name in subcat_objects else None,
                synonyms=synonyms, 
                default_unit=unit
            )

        p1 = create_prod("Arroz Costeño Graneadito", "Abarrotes", "Arroz", ["arroz", "kilo de arroz"], "kg")
        p2 = create_prod("Cerveza Pilsen Callao 630ml", "Bebidas", "Cervezas", ["chela", "birra", "pilsen"], "botella")
        p3 = create_prod("Coca Cola 1.5L", "Bebidas", "Gaseosas", ["gaseosa", "coca"], "botella")
        p4 = create_prod("Inca Kola 3L", "Bebidas", "Gaseosas", ["gaseosa", "inka"], "botella")
        p5 = create_prod("Inca Kola 2L", "Bebidas", "Gaseosas", ["gaseosa", "inka"], "botella")
        p6 = create_prod("Inca Kola 1.5L", "Bebidas", "Gaseosas", ["gaseosa", "inka"], "botella")
        p7 = create_prod("Inca Kola 500ml", "Bebidas", "Gaseosas", ["gaseosa", "inka", "personal"], "botella")

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
    print("\n🔧 HERRAMIENTA DE BASE DE DATOS")
    print("=" * 40)
    print("1. MIGRAR - Agregar columnas nuevas (NO borra datos)")
    print("2. RESET  - Borrar TODO y recrear desde cero")
    print("=" * 40)
    
    opcion = input("Elige opción (1/2): ").strip()
    
    if opcion == "1":
        migrate_database()
    elif opcion == "2":
        confirmacion = input("⚠️ Esto BORRARÁ todos los datos. Escribir 'BORRAR' para confirmar: ")
        if confirmacion == "BORRAR":
            reset_database()
        else:
            print("❌ Operación cancelada.")
    else:
        print("❌ Opción inválida.")
import sys
import os
from sqlalchemy import text 

# Ajuste para importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal, engine
from app.models.tables import Base, Category, SubCategory

def migrate_subcategories():
    print("🚀 Iniciando migración de subcategorías...")
    
    # 1. Crear tabla subcategories
    # (SQLAlchemy crea solo si no existe)
    Base.metadata.create_all(bind=engine)
    print("✅ Tabla 'subcategories' verificada/creada.")

    db = SessionLocal()
    try:
        # 2. Agregar columna subcategory_id a MasterProduct si no existe
        print("   - Verificando columna 'subcategory_id' en master_products...")
        with engine.connect() as connection:
            try:
                connection.execute(text("ALTER TABLE master_products ADD COLUMN IF NOT EXISTS subcategory_id INTEGER REFERENCES subcategories(id)"))
                print("     ✅ Columna 'subcategory_id' verificada")
            except Exception as e:
                print(f"     ⚠️ Error verificando columna: {e}")
            connection.commit()

        # 3. Sembrar Subcategorías por defecto
        print("🌱 Sembrando subcategorías base...")
        
        # Mapa: Categoria General -> [Lista de Subcategorías]
        seed_data = {
            "Bebidas": ["Gaseosas", "Agua", "Cervezas", "Energizantes", "Jugos", "Licores", "Vinos"],
            "Abarrotes": ["Arroz", "Azúcar", "Aceites", "Fideos", "Conservas", "Menestras", "Snacks", "Golosinas", "Panadería", "Embutidos", "Verduras", "Frutas", "Condimentos"],
            "Limpieza": ["Detergentes", "Jabones", "Desinfectantes", "Papel Higiénico"],
            "Cuidado Personal": ["Shampoo", "Desodorante", "Pasta Dental", "Farmacia", "Cremas"],
            "Otros": ["Mascotas", "Hogar", "Útiles Escolares", "Tecnología"]
        }

        count = 0
        for cat_name, subcats in seed_data.items():
            # Buscar ID de la categoría padre
            parent = db.query(Category).filter(Category.name == cat_name).first()
            if parent:
                for sub_name in subcats:
                    # Verificar si existe
                    exists = db.query(SubCategory).filter(
                        SubCategory.category_id == parent.id,
                        SubCategory.name == sub_name
                    ).first()
                    
                    if not exists:
                        new_sub = SubCategory(name=sub_name, category_id=parent.id)
                        db.add(new_sub)
                        count += 1
                        print(f"   ➕ {cat_name} -> {sub_name}")
            else:
                print(f"   ⚠️ Categoría padre '{cat_name}' no encontrada. Saltando...")

        db.commit()
        print(f"✅ Migración terminada. {count} subcategorías creadas.")

    except Exception as e:
        print(f"❌ Error durante la migración: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate_subcategories()

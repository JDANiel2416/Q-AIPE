import sys
import os

# Agregar el directorio raíz del proyecto al PYTHONPATH
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from sqlalchemy import text
from app.db.session import SessionLocal, engine
from app.models.tables import Base, Category, MasterProduct

def migrate_categories():
    print("🚀 Iniciando migración de categorías...")
    
    # 1. Crear la tabla 'categories' si no existe
    # Nota: create_all comprueba si existen, pero como acabamos de añadirla al modelo,
    # SQLAlchemy detectará que falta y la creará.
    Base.metadata.create_all(bind=engine)
    print("✅ Tablas sincronizadas (Category creada si no existía).")

    db = SessionLocal()
    try:
        # 2. Obtener todas las categorías únicas actuales (String)
        # Normalizamos a Title Case para evitar duplicados como "BEBIDAS" y "Bebidas"
        products = db.query(MasterProduct).all()
        
        unique_categories = set()
        for p in products:
            if p.category:
                # Normalización simple: Capitalize
                cat_name = p.category.strip().title() 
                unique_categories.add(cat_name)
        
        # Agregar categorías por defecto si no existen
        defaults = ["Bebidas", "Abarrotes", "Limpieza", "Otros"]
        for d in defaults:
            unique_categories.add(d)

        print(f"📊 Categorías detectadas: {unique_categories}")

        # 3. Insertar en la tabla Category
        cat_map = {} # Nombre -> ID
        
        for cat_name in unique_categories:
            existing = db.query(Category).filter(Category.name == cat_name).first()
            if not existing:
                # Asignar icono por defecto según nombre (simple heurística)
                icon = "category_outlined"
                if "Bebida" in cat_name: icon = "local_drink_outlined"
                elif "Abarrote" in cat_name: icon = "shopping_basket_outlined"
                elif "Limpieza" in cat_name: icon = "cleaning_services_outlined"

                new_cat = Category(name=cat_name, icon_name=icon)
                db.add(new_cat)
                db.flush() # Para obtener el ID
                cat_map[cat_name] = new_cat.id
                print(f"   ➕ Creada categoría: {cat_name}")
            else:
                cat_map[cat_name] = existing.id
                print(f"   ℹ️ Ya existía: {cat_name}")

        # 4. Actualizar MasterProducts con el ID
        print("🔄 Vinculando productos a categorías...")
        count = 0
        for p in products:
            if p.category:
                cat_name = p.category.strip().title()
                if cat_name in cat_map:
                    p.category_id = cat_map[cat_name]
                    count += 1
        
        db.commit()
        print(f"✅ Migración completada! {count} productos actualizados.")

    except Exception as e:
        print(f"❌ Error durante la migración: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate_categories()

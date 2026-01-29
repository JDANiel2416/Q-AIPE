import sys
import os
from sqlalchemy import text 

# Ajuste para importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import Category, MasterProduct

def consolidate_categories():
    print("🧹 Iniciando limpieza y consolidación de categorías...")
    db = SessionLocal()
    
    # 1. Definir las categorías GENERALES que queremos conservar/crear
    general_categories = {
        "Bebidas": "local_drink_outlined",
        "Abarrotes": "shopping_basket_outlined",
        "Limpieza": "cleaning_services_outlined",
        "Cuidado Personal": "wash_outlined", # Nuevo, para jabones, shampoo, farmacia
        "Otros": "category_outlined"
    }

    # Mapa de MIGRACION: Granular -> General
    mapping = {
        # A Bebidas
        "Licores": "Bebidas",
        "Refrescos": "Bebidas",
        
        # A Abarrotes (La gran mayoría)
        "Snacks": "Abarrotes",
        "Golosinas": "Abarrotes",
        "Panadería": "Abarrotes",
        "Lácteos": "Abarrotes",
        "Embutidos": "Abarrotes",
        "Verduras": "Abarrotes",
        "Frutas": "Abarrotes",
        "Helados": "Abarrotes",
        
        # A Cuidado Personal
        "Aseo Personal": "Cuidado Personal",
        "Farmacia": "Cuidado Personal",
        
        # A Limpieza
        "Limpieza del Hogar": "Limpieza",
        
        # A Otros
        "Útiles Escolares": "Otros",
        "Hogar": "Otros",
        "Mascotas": "Otros"
    }

    try:
        # 2. Asegurar que existan las categorías generales
        general_cat_ids = {} # Nombre -> ID
        
        for name, icon in general_categories.items():
            cat = db.query(Category).filter(Category.name == name).first()
            if not cat:
                print(f"   ✨ Creando general: {name}")
                cat = Category(name=name, icon_name=icon)
                db.add(cat)
                db.flush()
            else:
                cat.icon_name = icon # Actualizar icono por si acaso
                
            general_cat_ids[name] = cat.id
        
        db.commit() # Guardar generales

        # 3. Reasignar Productos
        print("   🔄 Reasignando productos...")
        
        # Iterar sobre el mapa y mover productos
        for old_name, new_name in mapping.items():
            old_cat = db.query(Category).filter(Category.name == old_name).first()
            
            if old_cat:
                target_id = general_cat_ids[new_name]
                
                # Buscar productos en la categoría vieja
                products = db.query(MasterProduct).filter(MasterProduct.category_id == old_cat.id).all()
                count = 0
                for p in products:
                    p.category_id = target_id
                    p.category = new_name # Actualizamos string legacy
                    count += 1
                
                print(f"      ➡️ Moviendo {count} productos de '{old_name}' a '{new_name}'")
                
                # Una vez vacía, borramos la categoría vieja
                db.delete(old_cat)
        
        db.commit()
        print("✅ Consolidación terminada con éxito.")

    except Exception as e:
        print(f"❌ Error consolidando: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    consolidate_categories()

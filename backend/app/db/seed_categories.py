import sys
import os
from sqlalchemy import text 

# Ajuste para importar módulos de 'app'
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import Category

def seed_categories():
    print("🌱 Sembrando catálogo extendido de categorías...")
    db = SessionLocal()
    
    # Lista completa de categorías para una Bodega peruana
    new_categories = [
        {"name": "Snacks", "icon": "tapas_outlined"},
        {"name": "Golosinas", "icon": "cake_outlined"}, # O cookie
        {"name": "Útiles Escolares", "icon": "school_outlined"},
        {"name": "Aseo Personal", "icon": "wash_outlined"},
        {"name": "Limpieza del Hogar", "icon": "cleaning_services_outlined"}, # Renombrado de Limpieza
        {"name": "Farmacia", "icon": "medical_services_outlined"},
        {"name": "Panadería", "icon": "bakery_dining_outlined"},
        {"name": "Lácteos", "icon": "water_drop_outlined"}, # Leche/Yogurt
        {"name": "Embutidos", "icon": "restaurant_outlined"},
        {"name": "Verduras", "icon": "eco_outlined"},
        {"name": "Frutas", "icon": "nutrition_outlined"},
        {"name": "Hogar", "icon": "home_outlined"},
        {"name": "Mascotas", "icon": "pets_outlined"},
        {"name": "Helados", "icon": "icecream_outlined"},
    ]

    count = 0
    try:
        for cat_data in new_categories:
            # Verificar si existe (por nombre exacto)
            exists = db.query(Category).filter(Category.name == cat_data["name"]).first()
            if not exists:
                new_cat = Category(name=cat_data["name"], icon_name=cat_data["icon"])
                db.add(new_cat)
                count += 1
                print(f"   ➕ Agregada: {cat_data['name']}")
            else:
                # Opcional: Actualizar icono si ya existe
                pass
        
        db.commit()
        print(f"✅ Proceso terminado. {count} categorías nuevas agregadas.")
    except Exception as e:
        print(f"❌ Error sembrando categorías: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_categories()

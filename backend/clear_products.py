"""
Script para limpiar las tablas de productos: MasterProduct e Inventory.
ADVERTENCIA: Este script elimina TODOS los datos de productos.
"""

import sys
import os

# Agregar el directorio raíz al path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models.tables import MasterProduct, StoreInventory

def clear_products():
    """Elimina todos los productos de MasterProduct e StoreInventory."""
    db = SessionLocal()
    
    try:
        print("=" * 50)
        print("⚠️  SCRIPT DE LIMPIEZA DE PRODUCTOS")
        print("=" * 50)
        
        # Contar registros antes de eliminar
        inv_count = db.query(StoreInventory).count()
        master_count = db.query(MasterProduct).count()
        
        print(f"\n📊 Registros actuales:")
        print(f"   - StoreInventory: {inv_count}")
        print(f"   - MasterProduct: {master_count}")
        
        if inv_count == 0 and master_count == 0:
            print("\n✅ Las tablas ya están vacías. Nada que hacer.")
            return
        
        # Confirmar antes de proceder
        print("\n⚠️  ADVERTENCIA: Esta acción es IRREVERSIBLE.")
        confirm = input("¿Estás seguro de que quieres eliminar TODOS los productos? (escribe 'SI' para confirmar): ")
        
        if confirm.strip().upper() != "SI":
            print("\n❌ Operación cancelada.")
            return
        
        print("\n🔄 Iniciando limpieza...")
        
        # Orden de eliminación (respetando foreign keys):
        # 1. StoreInventory (depende de MasterProduct)
        # 2. MasterProduct
        
        print("   [1/2] Eliminando StoreInventory...")
        db.query(StoreInventory).delete()
        db.commit()
        print(f"         ✓ {inv_count} StoreInventory eliminados")
        
        print("   [2/2] Eliminando MasterProducts...")
        db.query(MasterProduct).delete()
        db.commit()
        print(f"         ✓ {master_count} MasterProducts eliminados")
        
        print("\n" + "=" * 50)
        print("✅ LIMPIEZA COMPLETADA EXITOSAMENTE")
        print("=" * 50)
        print("\nPuedes empezar a agregar productos desde cero.")
        
    except Exception as e:
        db.rollback()
        print(f"\n❌ Error durante la limpieza: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    clear_products()

"""
Migración para agregar campos title e is_active a chat_sessions
Ejecutar desde la carpeta backend con: python migrations/add_chat_fields.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.db.session import engine

def migrate():
    with engine.connect() as conn:
        # Agregar columna title si no existe
        try:
            conn.execute(text("ALTER TABLE chat_sessions ADD COLUMN title VARCHAR"))
            print("✅ Columna 'title' agregada")
        except Exception as e:
            if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                print("ℹ️ Columna 'title' ya existe")
            else:
                print(f"⚠️ Error con 'title': {e}")
        
        # Agregar columna is_active si no existe
        try:
            conn.execute(text("ALTER TABLE chat_sessions ADD COLUMN is_active BOOLEAN DEFAULT TRUE"))
            print("✅ Columna 'is_active' agregada")
        except Exception as e:
            if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                print("ℹ️ Columna 'is_active' ya existe")
            else:
                print(f"⚠️ Error con 'is_active': {e}")
        
        conn.commit()
        print("🎉 Migración completada")

if __name__ == "__main__":
    migrate()

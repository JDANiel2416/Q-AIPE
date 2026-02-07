from app.db.session import engine
from sqlalchemy import inspect

def check_tables():
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print("Tables found:", tables)
    
    if "notifications" in tables:
        print("\nColumns in 'notifications':")
        for col in inspector.get_columns("notifications"):
            print(f"  - {col['name']} ({col['type']})")
    else:
        print("\n❌ Table 'notifications' NOT found!")

    if "users" in tables:
        print("\nColumns in 'users':")
        for col in inspector.get_columns("users"):
            print(f"  - {col['name']}")

if __name__ == "__main__":
    check_tables()

from app.db.session import SessionLocal
from app.models.tables import MasterProduct
import json

def inspect_product(pid):
    db = SessionLocal()
    p = db.query(MasterProduct).filter(MasterProduct.id == pid).first()
    if p:
        print(f"Product: {p.name}")
        print(f"Category: {p.category}")
        print(f"Attributes: {json.dumps(p.attributes, indent=2)}")
    else:
        print("Product not found")
    db.close()

if __name__ == "__main__":
    inspect_product(9)

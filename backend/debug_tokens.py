import sys
import os
sys.path.append(os.getcwd())

from app.db.session import SessionLocal
from app.models.tables import User, Bodega

db = SessionLocal()

print("=== TOKEN CHECK ===")

# Check all users with fcm_tokens
users = db.query(User).filter(User.fcm_token != None).all()

for u in users:
    print(f"User: {u.dni} | Role: {u.role}")
    print(f"  FCM Token: {u.fcm_token}")
    print(f"  Token Length: {len(u.fcm_token) if u.fcm_token else 0}")
    print()

# Check the bodega owner
bodegas = db.query(Bodega).all()
for b in bodegas:
    owner = db.query(User).filter(User.id == b.owner_id).first()
    if owner:
        print(f"Bodega: {b.name}")
        print(f"  Owner: {owner.full_name}")
        print(f"  Owner FCM: {owner.fcm_token}")
        print()

db.close()

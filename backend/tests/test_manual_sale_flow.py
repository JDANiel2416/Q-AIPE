import requests
import json
import time
import random

BASE_URL = "http://127.0.0.1:8000/api/v1"

def test_manual_sale_flow():
    print("--- Starting Manual Sale Flow Verification ---")
    timestamp = int(time.time())
    
    # 1. Register User (Bodeguero)
    dni = f"99{timestamp}"[-8:] # Ensure 8 digits
    password = "password123"
    phone = f"9{random.randint(10000000, 99999999)}" # 9 digits starting with 9
    payload = {
        "dni": dni,
        "password": password,
        "phone": phone,
        "role": "BODEGUERO",
        "bodega_name": f"Bodega Test {timestamp}",
        "latitude": -12.0,
        "longitude": -77.0
    }
    
    print(f"1. Registering user with DNI: {dni}")
    try:
        resp = requests.post(f"{BASE_URL}/auth/register", json=payload)
        if resp.status_code != 200:
            print(f"Failed to register: {resp.text}")
            return
        data = resp.json()
        user_id = data["user_id"]
        print(f"   Success! User ID: {user_id}")
    except Exception as e:
        print(f"Error registering: {e}")
        return

    # 2. Get Bodega ID (from profile or my-inventory)
    print("2. Getting Bodega ID...")
    try:
        resp = requests.get(f"{BASE_URL}/bodeguero/my-inventory?user_id={user_id}")
        data = resp.json()
        bodega_id = data.get("bodega_id")
        if not bodega_id:
            print("   Failed to get bodega_id")
            # Wait, maybe registration creates bodega asynchronously? Typically yes.
            # But the response usually has it.
            # Let's try get profile
            resp = requests.get(f"{BASE_URL}/bodeguero/profile?user_id={user_id}")
            profile = resp.json()
            # If backend creates based on user_id, maybe we use user_id to look up bodega?
            # Creating product uses user_id.
    except Exception as e:
        print(f"Error getting inventory: {e}")
        bodega_id = None # Logic might handle user_id lookup
        
    # 3. Add Product
    print("3. Adding Product with stock 1...")
    product_payload = {
        "name": "Coca Cola 3L",
        "category": "Bebidas",
        "price": 10.0,
        "stock": 1, 
        "attributes": {"image_url": "http://example.com/image.png"}
    }
    try:
        resp = requests.post(f"{BASE_URL}/bodeguero/add-product?user_id={user_id}", json=product_payload)
        if resp.status_code != 200:
            print(f"Failed to add product: {resp.text}")
            return
        p_data = resp.json()
        # The response structure might vary, let's assume success if 200
        # Need product_id. Let's list inventory to find it.
        resp = requests.get(f"{BASE_URL}/bodeguero/my-inventory?user_id={user_id}")
        inv_data = resp.json()
        products = inv_data.get("products", [])
        if not products:
             print("   No products found!")
             return
        product_id = products[0]["product_id"]
        bodega_id = inv_data.get("bodega_id") # Confirming bodega_id here
        print(f"   Success! Product ID: {product_id}, Bodega ID: {bodega_id}")
    except Exception as e:
        print(f"Error adding product: {e}")
        return

    # 4. Create Manual Reservation (Sale)
    print("4. Creating Manual Reservation (Sale)...")
    reservation_payload = {
        "user_id": user_id, # Bodeguero ID acting as seller
        "bodega_id": bodega_id,
        "items": [
            {
                "product_id": product_id,
                "product_name": "Coca Cola 3L",
                "quantity": 1,
                "unit_price": 10.0
            }
        ],
        "delivery_type": "PICKUP",
        "is_manual": True
    }
    
    try:
        resp = requests.post(f"{BASE_URL}/reservations/create", json=reservation_payload)
        if resp.status_code != 200:
            print(f"Failed to create reservation: {resp.text}")
            return
        print("   Success! Sale recorded.")
    except Exception as e:
        print(f"Error creating reservation: {e}")
        return

    # 5. Verify Stock is 0
    print("5. Verifying Stock is 0...")
    try:
        resp = requests.get(f"{BASE_URL}/bodeguero/my-inventory?user_id={user_id}")
        inv_data = resp.json()
        products = inv_data.get("products", [])
        product = next((p for p in products if p["product_id"] == product_id), None)
        if product and product["stock"] == 0:
            print("   Success! Stock is 0.")
        else:
            print(f"   Failed! Stock is {product['stock'] if product else 'Not Found'}")
            return
    except Exception as e:
        print(f"Error checking stock: {e}")
        return
        
    # 6. Verify Notification (Stock Alert)
    print("6. Verifying Notification...")
    # Give a brief moment for async notification creation if needed (though it's synchronous in code)
    try:
        resp = requests.get(f"{BASE_URL}/notifications?user_id={user_id}")
        if resp.status_code != 200:
             print(f"Failed to get notifications: {resp.text}")
             return
        notifications = resp.json()
        # Look for STOCK_ALERT
        found = False
        for n in notifications:
            if n["type"] == "STOCK_ALERT" and "Coca Cola" in n["message"]:
                 found = True
                 safe_title = n['title'].encode('ascii', 'replace').decode()
                 safe_msg = n['message'].encode('ascii', 'replace').decode()
                 print(f"   Success! Notification found: {safe_title} - {safe_msg}")
                 break
        if not found:
            print("   Failed! Notification not found.")
            safe_notifs = str(notifications).encode('ascii', 'replace').decode()
            print(f"   All notifications: {safe_notifs}")
    except Exception as e:
         print(f"Error checking notifications: {e}")

if __name__ == "__main__":
    test_manual_sale_flow()

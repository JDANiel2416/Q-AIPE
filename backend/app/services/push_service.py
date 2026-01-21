"""
Firebase Cloud Messaging Push Service
Envía notificaciones push a dispositivos Android/iOS
"""
import json
import httpx
from google.oauth2 import service_account
from google.auth.transport.requests import Request
import os

# Ruta al archivo de credenciales de Firebase
CREDENTIALS_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "firebase-credentials.json")

# Scopes necesarios para FCM
SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

def get_access_token() -> str:
    """Obtiene un token de acceso OAuth2 para la API de FCM."""
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH, scopes=SCOPES
    )
    credentials.refresh(Request())
    return credentials.token

def get_project_id() -> str:
    """Obtiene el project_id del archivo de credenciales."""
    with open(CREDENTIALS_PATH, "r") as f:
        data = json.load(f)
    return data.get("project_id", "")

async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict = None
) -> bool:
    """
    Envía una notificación push a un dispositivo específico.
    
    Args:
        fcm_token: Token FCM del dispositivo destino
        title: Título de la notificación
        body: Cuerpo/mensaje de la notificación
        data: Datos adicionales (opcional)
    
    Returns:
        True si se envió correctamente, False en caso de error
    """
    if not fcm_token:
        print("⚠️ No FCM token provided, skipping push notification")
        return False
    
    try:
        access_token = get_access_token()
        project_id = get_project_id()
        
        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        # Construir el mensaje FCM
        message = {
            "message": {
                "token": fcm_token,
                "notification": {
                    "title": title,
                    "body": body
                },
                "android": {
                    "priority": "high",
                    "notification": {
                        "channel_id": "high_importance_channel",
                        "sound": "default",
                        "default_vibrate_timings": True,
                        "notification_priority": "PRIORITY_MAX"
                    }
                }
            }
        }
        
        # Agregar datos adicionales si existen
        if data:
            message["message"]["data"] = {k: str(v) for k, v in data.items()}
        
        async with httpx.AsyncClient() as client:
            response = await client.post(url, headers=headers, json=message)
            
            if response.status_code == 200:
                print(f"✅ Push notification sent successfully to token: {fcm_token[:20]}...")
                return True
            else:
                print(f"❌ FCM Error: {response.status_code} - {response.text}")
                return False
                
    except Exception as e:
        print(f"❌ Error sending push notification: {e}")
        return False

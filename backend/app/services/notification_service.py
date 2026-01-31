import requests
import json
from app.core.config import settings
from app.core.security import decrypt_value

class NotificationService:
    def __init__(self):
        self.app_id = settings.ONESIGNAL_APP_ID
        self.api_key = settings.ONESIGNAL_API_KEY
        self.base_url = "https://onesignal.com/api/v1/notifications"


    def send_notification(self, title: str, message: str, player_ids: list = None, data: dict = None):
        """
        Envía una notificación push vía OneSignal.
        
        Args:
            title (str): Título de la notificación.
            message (str): Cuerpo del mensaje.
            player_ids (list, optional): Lista de IDs de dispositivos (Base64 Encrypted). 
                                       Si es None, envía a TODOS (Segments: ['All']).
            data (dict, optional): Datos adicionales para enviar en el payload.
        """
        
        # Los tokens FCM/OneSignal se guardan en texto plano (no encriptados)
        # así que los usamos directamente sin desencriptar
        valid_ids = [pid for pid in (player_ids or []) if pid]
        
        
        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Basic {self.api_key}"
        }

        payload = {
            "app_id": self.app_id,
            "headings": {"en": title},
            "contents": {"en": message},
            "data": data or {}
        }

        if valid_ids:
            payload["include_player_ids"] = valid_ids
            # DEBUG: Log exact token being sent
            print(f"DEBUG TOKEN BEING SENT: {valid_ids}")
        else:
            payload["included_segments"] = ["All"]

        try:
            response = requests.post(self.base_url, headers=headers, data=json.dumps(payload))
            response_data = response.json()
            
            if response.status_code == 200:
                if "errors" in response_data:
                    print(f"⚠️ OneSignal respondió 200 pero con errores: {response_data}")
                    # Si el ID es inválido, indicarlo claramente
                    if "invalid_player_ids" in response_data.get("errors", {}):
                        print("❌ El Player ID del usuario no es válido o ha expirado. El usuario debe volver a iniciar sesión.")
                    return False
                
                print(f"✅ Notificación enviada exitosamente: {response_data}")
                return True
            else:
                print(f"❌ Error HTTP enviando notificación ({response.status_code}): {response.text}")
                return False
        except Exception as e:
            print(f"❌ Excepción enviando notificación: {e}")
            return False

# Instancia global
notification_service = NotificationService()

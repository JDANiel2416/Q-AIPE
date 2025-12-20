from google import genai
from google.genai import types
from app.core.config import settings
import json

class GeminiService:
    def __init__(self):
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)
        self.model_name = "gemini-2.5-flash"

    async def interpret_search_intent(self, user_query: str, history: list) -> list:
        # Convertimos el historial a texto para que Gemini lo lea
        history_str = "\n".join([f"{msg['role']}: {msg['content']}" for msg in history[-6:]]) # Últimos 6 mensajes

        prompt = f"""
        Eres el cerebro de una App de Delivery en Perú.
        Tu trabajo es identificar QUÉ PRODUCTOS quiere buscar el usuario en la base de datos.
        
        HISTORIAL DE CONVERSACIÓN:
        {history_str}
        
        INPUT ACTUAL DEL USUARIO: "{user_query}"
        
        REGLAS:
        1. Si el usuario dice "agrega X", "junta con lo anterior" o "todo junto", DEBES combinar los productos del historial con los nuevos.
        2. Si el usuario cambia de tema, ignora el historial de productos anterior.
        3. Traduce jerga: "Gorda" -> "Gaseosa 3L", "Chela" -> "Cerveza".
        4. Si no hay productos (solo saludo), devuelve lista vacía.
        
        OUTPUT (JSON Array EXCLUSIVAMENTE):
        Ejemplo: [{{"product_name": "Arroz"}}, {{"product_name": "Coca Cola"}}]
        """

        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            return json.loads(response.text)
        except Exception as e:
            print(f"Error Gemini Intent: {e}")
            return []

    async def generate_shopkeeper_response(self, user_query: str, context_str: str) -> str:
        prompt = f"""
        Actúa como "Keaype", un asistente virtual amable y eficaz que ayuda a vecinos de Huanchaco (Perú) a encontrar productos en MÚLTIPLES bodegas.
        NO eres dueño de ninguna bodega. Eres el intermediario que busca en todas.
        
        Input Cliente: "{user_query}"
        Resultado de la búsqueda en BD: "{context_str}"
        
        Reglas:
        1. Habla en plural ("Busqué en las bodegas...", "Encontré estas opciones...").
        2. Sé breve, amable y usa jerga peruana leve ("Vecino", "Al toque").
        3. Nunca digas "Tengo stock", di "Encontré stock en...".
        4. Si no hay resultados, sugiere buscar con otros términos.
        
        Output: Solo el texto de respuesta.
        """
        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="text/plain")
            )
            return response.text.strip()
        except Exception:
            return "Aquí tienes los resultados de las bodegas cercanas, vecino."

    async def process_bodeguero_audio(self, audio_file_path: str):
        myfile = self.client.files.upload(path=audio_file_path)
        prompt = """
        Identifica productos y cantidades.
        Output JSON: {"action": "UPDATE_STOCK", "items": [{"product_normalized": "string", "quantity_to_add": int}]}
        """
        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=[myfile, prompt],
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            return json.loads(response.text)
        except Exception:
            return {"error": "Error audio"}

gemini_client = GeminiService()
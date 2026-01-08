from google import genai
from google.genai import types
from app.core.config import settings
import json
import random
import time

class GeminiService:
    def __init__(self):
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
        # LISTA DE MODELOS DISPONIBLES (Priorizados por velocidad/calidad)
        # Puedes reordenarlos según tu preferencia
        self.available_models = [
            "gemini-2.0-flash-lite",    # Muy rápido y ligero
            "gemini-2.5-flash",
            "gemini-2.5-flash-preview-09-2025",
            "gemini-2.5-flash-lite",
            "gemini-3-flash-preview",
            "gemini-2.5-pro",
            "gemini-3-pro-preview"
        ]
        self.current_model_index = 0

    @property
    def model_name(self):
        """Devuelve el modelo actual de la rotación."""
        return self.available_models[self.current_model_index]

    def _rotate_model(self):
        """Cambia al siguiente modelo en la lista."""
        old_model = self.model_name
        self.current_model_index = (self.current_model_index + 1) % len(self.available_models)
        print(f"⚠️ [GEMINI] Cuota excedida en {old_model}. Cambiando a -> {self.model_name}")

    async def _execute_with_retry(self, func, *args, **kwargs):
        """
        Ejecuta una función de Gemini. Si falla por cuota (429), rota el modelo y reintenta.
        Intenta con TODOS los modelos disponibles antes de rendirse.
        """
        attempts = 0
        max_attempts = len(self.available_models)

        while attempts < max_attempts:
            try:
                # Ejecutamos la llamada al API
                return func(*args, **kwargs)
            
            except Exception as e:
                error_str = str(e)
                # Detectar error 429 (Resource Exhausted)
                if "429" in error_str or "RESOURCE_EXHAUSTED" in error_str:
                    self._rotate_model()
                    attempts += 1
                    # Pequeña pausa para no saturar si rota muy rápido
                    time.sleep(0.5) 
                else:
                    # Si es otro error (ej. JSON mal formado, error de red), lanzarlo normal
                    raise e
        
        # Si probamos todos y fallaron
        print("❌ [GEMINI] Se agotaron las cuotas de TODOS los modelos disponibles.")
        raise Exception("Servicio Gemini no disponible temporalmente (Cuota agotada).")

    async def interpret_search_intent(self, user_query: str, history: list) -> list:
        history_str = "\n".join([f"{msg['role']}: {msg['content']}" for msg in history[-6:]])

        prompt = f"""
        Eres el cerebro de búsqueda de "Q-AIPE", una app de delivery de bodegas.
        HISTORIAL: {history_str}
        INPUT USUARIO: "{user_query}"
        
        TAREA:
        Analiza qué productos quiere el usuario, en QUÉ CANTIDAD y sus CARACTERÍSTICAS.
        
        REGLAS CRÍTICAS:
        1. **Nombre del producto es LO MÁS IMPORTANTE** - Siempre prioriza identificar el producto base.
        2. **CONTEXTO HISTÓRICO - MODIFICACIÓN VS ADICIÓN**:
           - Si dice "cambia por...", "mejor dame...", "no, quiero...": REEMPLAZA el producto anterior.
           - Si dice "AGREGA", "TAMBIÉN", "Y UNO DE...", "ADICIONA", "SEPARA": **ESTRICTAMENTE MANTÉN** los productos del historial y **AGREGA** el nuevo al array.
             ¡TU SALIDA DEBE CONTENER UNA LISTA CON EL PRODUCTO ANTERIOR Y EL NUEVO!
             Ejemplo: Historial=[Coca], User="agrega arroz" -> Output=[Coca, Arroz]. NO devuelvas solo [Arroz].
           - Si dice "OTRA", "ESA", "SIMILAR": Resuelve la referencia (mismo producto, dif atributos).
        3. **Características de TAMAÑO son PREFERENCIAS**:
           - Ponlas en "preferred_attributes".
           - Solo usa "must_contain" para variantes estrictas (Zero, Sin Gas).
        4. **Variantes del MISMO producto** → genera objetos SEPARADOS.
        
        EJEMPLOS:
        
        Historial: [User: "Quiero Inca Kola 3L", Bot: "No tengo 3L"]
        Input: "¿no tienes otra?"
        Output: [
          {{
            "product_name": "Inca Kola",
            "quantity": 1,
            "must_contain": [], 
            "must_not_contain": ["3L", "3 litros"], 
            "preferred_attributes": []
          }}
        ]
        
        Input: "quiero una gaseosa de 2 litros una inka kola"
        Output: [
          {{
            "product_name": "Inca Kola",
            "quantity": 1,
            "must_contain": ["gaseosa"],
            "must_not_contain": [],
            "preferred_attributes": ["2 litros", "2L", "2000ml"]
          }}
        ]
        
        ESTRUCTURA JSON:
        [{{
          "product_name": "Nombre",
          "quantity": 1,
          "must_contain": [],
          "must_not_contain": [],
          "preferred_attributes": []
        }}]
        
        DEVUELVE SOLO EL JSON ARRAY.
        """

        def _call_gemini():
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            return json.loads(response.text)

        try:
            return await self._execute_with_retry(_call_gemini)
        except Exception as e:
            print(f"Error Gemini Intent Final: {e}")
            return []

    async def generate_shopkeeper_response(self, user_query: str, context_str: str) -> str:
        prompt = f"""
        Actúa como "Q-AIPE", asistente de bodegas en Huanchaco, Perú.
        
        Input Cliente: "{user_query}"
        Resultado BD: "{context_str}"
        
        Reglas de Respuesta:
        1. **Sé breve y natural** - Máximo 2-3 líneas
        2. **Usa jerga peruana casual** - "vecino", "causa", "pata" (moderadamente)
        3. **Sé específico** - Menciona cantidades y precios si están disponibles
        4. **Si hay resultados** - Confirma que encontraste y da detalles breves
        5. **Si NO hay resultados** - Sugiere alternativas o pregunta si quiere algo similar
        6. **Evita redundancia** - No repitas exactamente lo que dice el context_str
        
        Ejemplos:
        - Input: "quiero una inca kola de 2 litros"
          Context: "Se encontró: Gaseosa Inca Kola 2L a S/7.50"
          Respuesta: "¡Listo vecino! 🍹 Tengo Inca Kola de 2L a S/7.50 en la bodega más cercana."
        
        - Input: "cerveza pilsen grande"
          Context: "Se encontró: Cerveza Pilsen 630ml a S/8.50"
          Respuesta: "Claro, tengo Pilsen de 630ml a S/8.50, vecino 🍺"
        
        - Input: "coca cola de 3 litros"
          Context: "No se encontraron coincidencias. Productos similares: Coca Cola 2L, Coca Cola 1.5L"
          Respuesta: "No tengo de 3L causa, pero sí hay de 2L y 1.5L. ¿Te sirve alguna? 🥤"
        """
        
        def _call_gemini():
            response = self.client.models.generate_content(
                model=self.model_name, 
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="text/plain")
            )
            return response.text.strip()

        try:
            return await self._execute_with_retry(_call_gemini)
        except Exception:
            return "Aquí tienes los resultados, vecino."

    async def process_bodeguero_audio(self, audio_file_path: str):
        # Para archivos, la lógica es más compleja porque el archivo se sube.
        # Por simplicidad, aquí intentamos con el modelo actual, si falla tocaría re-subir.
        try:
            myfile = self.client.files.upload(path=audio_file_path)
            prompt = """Identifica productos y cantidades. JSON: {"action": "UPDATE_STOCK", ...}"""
            
            def _call_gemini():
                response = self.client.models.generate_content(
                    model=self.model_name,
                    contents=[myfile, prompt],
                    config=types.GenerateContentConfig(response_mime_type="application/json")
                )
                return json.loads(response.text)

            return await self._execute_with_retry(_call_gemini)

        except Exception as e:
            print(f"Error audio: {e}")
            return {"error": "Error procesando audio"}

gemini_client = GeminiService()
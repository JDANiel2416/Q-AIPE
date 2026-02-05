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
            "gemini-2.5-flash-lite",    # Muy rápido y ligero
            "gemini-2.0-flash",
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

    async def validate_product_name(self, product_name: str) -> dict:
        """
        Valida si el nombre del producto es apropiado y comercializable.
        Retorna: { "is_valid": bool, "reason": str }
        """
        prompt = f"""
        Rol: Eres un moderador de contenido experto en jerga peruana y albur (doble sentido) para una app de bodegas.
        Tarea: Validar si "{product_name}" es un nombre de producto COMERCIALMENTE VÁLIDO y SEGURO.

        CRITERIOS DE RECHAZO estricto (is_valid = false):
        1. Obscenidades explícitas o IMPLÍCITAS.
           - Juegos de palabras fonéticos: "No MeJo Das" (No me jodas), "Elver Galarga", "Lustra Sable", "Kchero", "Rosa Melano".
           - Leet Speak / Sustituciones: "G4mp1" (Gampi), "P3n3", "C4c4", "Put0".
        2. Jerga peruana soez o vulgar.
        3. Contenido sexual, violento o discriminatorio.
        4. Gibberish (texto sin sentido) o Spam.
        5. Nombres que NO son palabras (Solo números o símbolos, ej: "123456", "!!!", "@@@").
        6. Nombres genéricos inútiles ("producto", "cosa").
        
        CRITERIOS DE ACEPTACIÓN (is_valid = true):
        1. Nombres de productos reales (ej: "Gaseosa Coca Cola", "Leche de Tigre", "Rompe Pecho").
           - Contexto: Es una bodega. "Leche", "Huevos", "Pechuga" son válidos.
           - Números con contexto ESTÁN BIEN (ej: "7 Up", "Coca Cola Zero").
        2. Errores ortográficos menores son ACEPTABLES.

        SI DETECTAS DOBLE SENTIDO, LEET SPEAK VULGAR, O FONÉTICA VULGAR -> RECHAZA.

        Responde SOLO JSON:
        {{
            "is_valid": true/false,
            "reason": "Explicación breve si es false (indica el albur/código detectado), o null si es true"
        }}
        """

        def _call():
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1
                )
            )
            return json.loads(response.text)

        try:
            return await self._execute_with_retry(_call)
        except Exception as e:
            print(f"Error validando producto: {e}")
            return {"is_valid": True, "reason": None}

    async def classify_intent(self, user_query: str) -> dict:
        """
        Clasifica la intención del usuario.
        Retorna un dict con:
        - intent: GREETING, FAREWELL, SEARCH, ADD_TO_PREVIOUS, MODIFY_PREVIOUS, 
                  RECALL_PREVIOUS, CLEAR_CART, QUESTION, CONFIRMATION, INAPPROPRIATE, UNKNOWN
        - requires_search: bool - si necesita buscar productos
        - requires_state: bool - si necesita el estado anterior
        - clear_state: bool - si debe limpiar el estado
        - is_inappropriate: bool - si es contenido inapropiado que debe ignorarse
        """
        prompt = f"""
        Eres el clasificador de intenciones de "Chek", app de delivery de bodegas en Perú.
        
        INPUT USUARIO: "{user_query}"
        
        CLASIFICA la intención en UNA de estas categorías:
        
        1. "CLARIFICATION_NEEDED" - [PRIORIDAD MÁXIMA] El usuario pide un producto pero falta TAMAÑO, PESO o VARIANTE CRÍTICA.
            - Ejemplos: "Quiero agua", "Dame arroz", "Quiero una Inca Kola" (Falta tamaño).
            - EXCEPCIÓN CRÍTICA: SI EL INPUT CONTIENE "3 LITROS", "1.5", "500ML", "PERSONAL", "VIDRIO", "KILO" -> NO ES CLARIFICATION. ES SEARCH O ADD.
        2. "SEARCH" - Búsqueda ESPECÍFICA (Tiene Marca Y Tamaño/Variante) O PREGUNTA POR MARCA CONCRETA: 
           - "Agua San Mateo con gas", "Arroz Costeño 1kg", "Coca Cola 3L".
           - SI EL USUARIO PIDE UNA MARCA ESPECÍFICA (ej: "¿Tienes Faraón?", "Arroz Costeño", "Pilsen"): ES SEARCH (Aunque falte tamaño, busca para ver si existe).
           - SI EL USUARIO RESPONDE DETALLES: "la de 3 litros", "personal porfa" -> ES SEARCH.
           - O productos que son únicos (ej: "Sal", "Fósforos").
        3. "GREETING" - Saludos: hola, buenos días.
        4. "FAREWELL" - Despedidas: chau, bye.
        5. "ADD_TO_PREVIOUS" - Agregar: "y también...", "agrega X".
        6. "MODIFY_PREVIOUS" - Cambiar: "cambia A por B", "quita X".
        7. "RECALL_PREVIOUS" - Recordar: "¿qué pedí?".
        8. "CLEAR_CART" - Borrar: "borra todo".
        9. "QUESTION" - Pregunta info: "¿está abierto?".
        10. "CONFIRMATION" - "si", "ok", "dale".
        11. "INAPPROPRIATE" - Insultos/Spam.
        12. "UNKNOWN" - No se sabe.
        
        RESPONDE SOLO CON UN JSON:
        {{
            "intent": "CATEGORIA",
            "requires_search": true/false,
            "requires_state": true/false,
            "clear_state": true/false,
            "is_inappropriate": true/false
        }}
        
        REGLAS:
        - CLARIFICATION_NEEDED: requires_search=false, requires_state=false, clear_state=false, is_inappropriate=false
        - SEARCH: requires_search=true, requires_state=false, clear_state=false, is_inappropriate=false
        - ADD_TO_PREVIOUS/MODIFY_PREVIOUS: requires_search=true, requires_state=true, clear_state=false, is_inappropriate=false
        - RECALL_PREVIOUS: requires_search=false, requires_state=true, clear_state=false, is_inappropriate=false
        - CLEAR_CART: requires_search=false, requires_state=false, clear_state=true, is_inappropriate=false
        - QUESTION: requires_search=true, requires_state=false, clear_state=false, is_inappropriate=false
        - CONFIRMATION: requires_search=false, requires_state=true, clear_state=false, is_inappropriate=false
        - GREETING/FAREWELL: requires_search=false, requires_state=false, clear_state=false, is_inappropriate=false
        - INAPPROPRIATE: requires_search=false, requires_state=false, clear_state=false, is_inappropriate=true
        
        RAZONAMIENTO OBLIGATORIO ANTES DE RESPONDER (INTERNO):
        1. ¿El usuario mencionó un producto? Si NO -> GREETING/QUESTION/ETC.
        2. Si SÍ mencionó producto: ¿Dijo MARCA o VARIANT (Light, Sin Gas, Negra)?
           - NO dijo nada ("agua", "arroz") -> CLARIFICATION_NEEDED.
           - SÍ dijo ("agua san mateo", "arroz costeño", "inca cola") -> SEARCH.
        """

        def _call_gemini():
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            return json.loads(response.text)

        try:
            result = await self._execute_with_retry(_call_gemini)
            print(f"🎯 [INTENT] Clasificación: {result}")
            return result
        except Exception as e:
            print(f"Error clasificando intención: {e}")
            # Fallback: asumir búsqueda si no podemos clasificar
            return {
                "intent": "UNKNOWN",
                "requires_search": True,
                "requires_state": False,
                "clear_state": False,
                "is_inappropriate": False
            }

    async def interpret_search_intent(self, user_query: str, current_state: list, intent_type: str = "SEARCH", known_products: list = None, last_bot_message: str = "") -> list:
        """
        Interpreta la intención de búsqueda y actualiza el estado.
        intent_type indica si es SEARCH (nuevo), ADD (agregar) o MODIFY (modificar)
        """
        state_str = json.dumps(current_state, ensure_ascii=False, indent=2)

        known_prod_str = ""
        if known_products:
             known_prod_str = f"CATÁLOGO MAESTRO (ÚSALO COMO REFERENCIA PARA CORREGIR NOMBRES): {json.dumps(known_products, ensure_ascii=False)}"

        prompt = f"""
        Eres el cerebro de búsqueda de "Chek", una app de delivery de bodegas.
        
        {known_prod_str}
        
        ESTADO ACTUAL DEL PEDIDO (JSON):
        {state_str}
        
        ULTIMO MENSAJE DEL BOT: "{last_bot_message}"
        
        NUEVO INPUT USUARIO: "{user_query}"
        TIPO DE INTENCIÓN: {intent_type}
        
        TAREA:
        Basado en el ESTADO ACTUAL, el ULTIMO MENSAJE DEL BOT, el INPUT y el TIPO DE INTENCIÓN, genera el ESTADO RESULTANTE.
        
        REGLAS SEGÚN TIPO DE INTENCIÓN:
        
        0. **REGLA SUPREMA (PRIORIDAD AL INPUT)**:
           - Si el USUARIO menciona un nombre o marca explícita (ej: "Faraón", "Coca", "Inca") -> ¡TIENE PRIORIDAD SOBRE LA HISTORIA!
           - IGNORA lo que el bot dijo antes si el usuario está pidiendo algo NUEVO.
           - Ej: Bot dijo "¿Costeño?", Usuario dice "¿Faraón?" -> SALIDA: "Arroz Faraón" (NO Costeño).
        
        1. **SEARCH** (Búsqueda nueva o cambio de tema):
           - Extrae los productos nuevos del input.
           - Si el input es MUY GENÉRICO (ej: "agua", "arroz") y NO especifica marca ni tamaño, extráelo igual.
           - IMPORTANTE: Si menciona TAMAÑO, PESO o VARIANTE (ej: "3 litros", "1.5", "personal", "light", "grande"), DEBES PONERLO EN `preferred_attributes`.
        
        2. **ADD_TO_PREVIOUS** (Agregar):
           - MANTÉN todos los productos del estado actual.
           - AÑADE los nuevos productos mencionados.
        
        3. **MODIFY_PREVIOUS/CONFIRMATION** (Modificar / Confirmar oferta):
           - SI EL USUARIO DICE "SI", "DALE", "AGREGALO" Y EL BOT OFRECE ALGO:
             - Mira el ULTIMO MENSAJE DEL BOT. Si el bot dijo "No tengo X, tengo Y", y el usuario acepta:
             - ACTUALIZA el estado: Reemplaza X por Y (la oferta del bot).
           - SI DETECTAS "QUITAR", "ELIMINAR", "SACAR", "X":
             - Busca el producto mencionado en el estado anterior y ELIMÍNALO (no lo incluyas en la salida).
             - Ej: Input "Quita la leche" -> Devuelve el estado SIN el objeto leche.
           - SI PIDE "CAMBIAR A por B": Elimina A (omítelo) y Agrega B (como nuevo).
           - SI PIDE CAMBIAR CANTIDAD: Busca el producto y actualiza quantity.
        
        4. **QUESTION** (Pregunta):
           - Extrae el producto sobre el que pregunta para buscarlo.
           - NO modifiques el estado anterior.
        
        REGLAS DE EXTRACCIÓN:
        - product_name: Nombre base del producto (Ej: "Inca Kola", "Arroz", "Leche").
        - quantity: Número entero (default: 1).
        - preferred_attributes: LISTA de strings con detalles clave (Tamaño, variante).
          - Ej: "Coca de 3L" -> product_name: "Coca Cola", preferred_attributes: ["3L"].
          - Ej: "Inca 1.5" -> product_name: "Inca Kola", preferred_attributes: ["1.5L"].
        
        ESTRUCTURA DE SALIDA (SIEMPRE UN ARRAY JSON):
        [
          {{
            "product_name": "Nombre",
            "quantity": 1,
            "must_contain": [],
            "must_not_contain": [],
            "preferred_attributes": ["3 litros", "helada"]
          }}
        ]
        
        IMPORTANTE: NO OLVIDES LOS ATRIBUTOS SI EL USUARIO LOS DICE.
        DEVUELVE SOLO EL JSON ARRAY ACTUALIZADO.
        """

        def _call_gemini():
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="application/json")
            )
            return json.loads(response.text)

        try:
            result = await self._execute_with_retry(_call_gemini)
            print(f"🧠 [INTENT EXTRACTION]: {json.dumps(result, ensure_ascii=False)}")
            return result
        except Exception as e:
            print(f"Error Gemini Intent Final: {e}")
            return current_state # Devolvemos el estado anterior en caso de error

    async def generate_conversational_response(self, user_query: str, intent_type: str, context: str = "", user_name: str = "Vecino", greeting_time: str = "Hola", available_options: str = "", avoid_greeting: bool = False) -> str:
        """
        Genera respuestas para saludos, despedidas, y PREGUNTAS DE CLARIFICACIÓN contextuadas.
        """
        
        greeting_instruction = ""
        # Prioridad 1: Clarificación siempre debe ser directa
        if intent_type == "CLARIFICATION_NEEDED":
             greeting_instruction = "INSTRUCCIÓN EXTRA: NO SALUDES DE NUEVO. VE DIRECTO AL GRANO."
        # Prioridad 2: Si el sistema pide evitar saludo (porque ya hay historial)
        elif avoid_greeting:
             greeting_instruction = "INSTRUCCIÓN EXTRA: NO SALUDES DE NUEVO. VE DIRECTO AL GRANO."
        else:
             greeting_instruction = f'USA SIEMPRE EL NOMBRE: "{greeting_time} {user_name}" o "Hola {user_name}".'
             
        # Construcción del contexto de disponibilidad para clarificación
        availability_context = ""
        if available_options:
            availability_context = f"\nINFORMACIÓN DE STOCK CERCA: {available_options}.\nUSA ESTO PARA SUGERIR OPCIONES REALES. (Ej: Si solo hay Normal, no ofrezcas Zero)."

        prompts = {
            "GREETING": f'''
                Actúa como "Cheko", asistente asistente de bodegas en Huanchaco, Perú.
                El usuario te saluda: "{user_query}"
                Nombre del usuario: "{user_name}"
                Saludo horario sugerido: "{greeting_time}"
                
                Responde con un saludo CORTO, FORMAL PERO AMIGABLE.
                {greeting_instruction}
                - MÁXIMO 10 PALABRAS.
            ''',
            "FAREWELL": f'''
                Actúa como "Cheko".
                El usuario se despide: "{user_query}"
                Nombre del usuario: "{user_name}"
                
                Despídete usando su nombre.
                - Corto y amable.
            ''',
            "CLEAR_CART": f'''
                El usuario limpia pedido: "{user_query}"
                Confirma acción usando su nombre "{user_name}" si cabe, o simple.
            ''',
            "RECALL_PREVIOUS": f'''
                Usuario pide recordar pedido anterior.
                Contexto: {context}
                Nombre: "{user_name}"
                Si hay pedido: "Hola {user_name}, tenías pendiente: ..."
                Si no: "{user_name}, no tienes pedidos guardados."
            ''',
            "CONFIRMATION": f'''
                Confirma la acción brevemente. "Entendido {user_name}".
            ''',
            "CLARIFICATION_NEEDED": f'''
                El usuario preguntó: "{user_query}"
                ACTÚA COMO BODEGUERO "CHEKO".
                El usuario fue IMPRECISO (faltan detalles clave).
                {greeting_instruction}
                {availability_context}
                
                CONOCIMIENTO DE MARCAS (SOLO SUGERIR SI TIENE SENTIDO CON EL PRODUCTO):
                - GASEOSAS: "Inca" (Inca Kola), "Coca" (Coca Cola)
                - CERVEZAS: "Pilsen", "Cristal", "Chela"
                - AGUAS: "San Mateo", "Cielo"
                - ARROZ: "Costeño", "Faraón"
                
                TU OBJETIVO: Preguntar SOLO por los detalles que faltan, SUGIRIENDO LO QUE SÍ HAY O LO LÓGICO.
                
                REGLAS DE ORO:
                1. SI HAY INFORMACIÓN DE STOCK (Arriba):
                   - ¡USA ESO! Es la verdad absoluta.
                
                2. SI NO HAY INFO DE STOCK:
                   - Si el usuario dijo algo raro (ej: "Arrozaje") y NO sabes qué es -> PREGUNTA QUÉ ES. NO INVENTES MARCAS NI TIPOS.
                   - ¡PROHIBIDO INVENTAR VARIEDADES! (No digas "blanco", "pre-cocido", "integral" si no sabes que hay).
                   - NO mezcles categorías.
                   - Pregunta genérico: "¿Qué marca prefieres?" o "¿De qué tamaño?".
                
                Responde CORTO y AMABLE usando "{user_name}".
            '''
        }
        
        prompt = prompts.get(intent_type, f"""
            Actúa como "Cheko".
            Input: "{user_query}"
            Nombre usuario: "{user_name}"
            Responde formal pero amable. MÁXIMO 2 líneas. NADA DE JERGAS.
        """)

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
            # Fallbacks según tipo
            fallbacks = {
                "GREETING": f"{greeting_time} {user_name}, ¿en qué te ayudo?",
                "FAREWELL": f"Hasta luego {user_name}.",
                "CLEAR_CART": "Listo, carrito vacío.",
                "RECALL_PREVIOUS": "No tienes pedidos guardados.",
                "CONFIRMATION": "Entendido."
            }
            return fallbacks.get(intent_type, "¿En qué te ayudo?")

    async def generate_shopkeeper_response(self, user_query: str, context_str: str, user_name: str = "Usuario", avoid_greeting: bool = False) -> str:
        
        greeting_instruction = ""
        if avoid_greeting:
            greeting_instruction = "7. EL USUARIO YA ESTÁ CONVERSANDO. NO DIGAS 'Hola' NI 'Estimado'. Responde DIRECTO a la pregunta."
        else:
             greeting_instruction = f'6. USA EL NOMBRE DEL USUARIO: "{user_name}" si encaja naturalmente.'

        prompt = f"""
        Eres "Cheko", un bodeguero EXPERTO y AMIGABLE de Huanchaco, Perú.
        Tu misión es emular a un tendero real que conoce sus productos y asesora al cliente.
        
        INFORMACIÓN DEL CLIENTE: El usuario preguntó por "{user_query}"
        RESULTADO DE BÚSQUEDA EN BD: {context_str}
        
        COMPORTAMIENTO "SMART SHOPKEEPER":
        1. **NO SEAS UN ROBOT**: No escupas listas si no estás seguro de lo que quiere.
        2. **INVESTIGA E INTERACTÚA**: 
           - Si el usuario pide algo VAGO (Ej: "Quiero agua", "tienes arroz?", "una gaseosa"), **NO LISTES TODO**.
           - PREGUNTA PRIMERO: "¿Qué marca prefieres? ¿San Mateo o Cielo? ¿Con o sin gas?" o "¿Arroz Costeño o Faraón? ¿De 1kg o saco?".
           - Guía al usuario para que especifique su pedido.
        3. **SI EL RESULTADO INDICA ITEMS "PARCIALES" O "ALTERNATIVAS"**:
           - **ESTO ES CRÍTICO**: Significa que no encontraste EXACTAMENTE lo que buscaba (ej: pidió 3L y solo hay 1.5L).
           - **TU MISIÓN**: NEGOCIAR. Dile: "Vecino, no me queda de 3L, pero tengo de 1.5L. ¿Le pongo dos de esas?".
           - NO digas simplemente "Aquí está tu pedido" si hay items parciales sin confirmar. OFRECE LA ALTERNATIVA.
        4. **SI TODO ESTÁ CORRECTO (ITEMS AGREGADOS)**:
           - Confirma la lista y el precio.
        5. **SI NO HAY STOCK**:
           - Ofrece alternativas REALES basadas en el RESULTADO DE BÚSQUEDA. (Ej: "No tengo San Mateo, pero tengo Cielo").
           - Si no hay nada parecido, dilo honestamente.
        
        TONO Y ESTILO:
        - Amable, servicial, experto.
        - {greeting_instruction}
        - NADA DE JERGAS EXCESIVAS ("causa" prohibido). Usa "vecino" si quieres ser amable, pero profesional.
        - Máximo 3-4 líneas.
        
        ANTI-ALUCINACIONES:
        - SOLO ofrece lo que ves en "RESULTADO DE BÚSQUEDA". Si la lista está vacía, NO TIENES EL PRODUCTO.
        
        TU RESPUESTA (solo el mensaje al cliente):
        """
        
        print(f"\n👤 [USER INPUT]: {user_query}")
        print(f"📝 [SHOPKEEPER PROMPT CONTEXT]:\n{context_str}")
        print("--------------------------------------------------\n")

        def _call_gemini():
            response = self.client.models.generate_content(
                model=self.model_name, 
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="text/plain")
            )
            raw_text = response.text.strip()
            
            # LIMPIEZA: Eliminar cualquier exposición accidental del prompt
            # A veces Gemini incluye partes del prompt en la respuesta
            lines_to_remove = [
                "Input Cliente:", "Input:", "Resultado BD:", "Resultado:", 
                "Context:", "Respuesta:", "TU RESPUESTA:", "INFORMACIÓN DEL CLIENTE:",
                "RESULTADO DE BÚSQUEDA:", "Actúa como", "Eres Cheko"
            ]
            
            cleaned_text = raw_text
            for line in lines_to_remove:
                if line.lower() in cleaned_text.lower():
                    # Eliminar la línea problemática y todo antes de ella
                    idx = cleaned_text.lower().find(line.lower())
                    # Buscar el siguiente salto de línea o punto
                    end_idx = cleaned_text.find("\n", idx)
                    if end_idx == -1:
                        end_idx = cleaned_text.find(".", idx)
                    if end_idx != -1:
                        cleaned_text = cleaned_text[end_idx+1:].strip()
                    else:
                        cleaned_text = cleaned_text[idx + len(line):].strip()
            
            # Si la respuesta quedó muy corta o vacía después de limpiar, usar fallback
            if len(cleaned_text) < 10:
                return "Aquí está lo que encontré, vecino 👀"
            
            return cleaned_text

        try:
            return await self._execute_with_retry(_call_gemini)
        except Exception:
            return "Aquí tienes los resultados, vecino."

    async def transcribe_audio(self, audio_file_path: str) -> str:
        """
        Transcribe audio file to text using Gemini.
        """
        try:
            # Upload file
            print(f"🎤 [GEMINI] Subiendo audio para transcripción: {audio_file_path}")
            myfile = self.client.files.upload(file=audio_file_path)
            
            prompt = "Transcribe EXACTLY what is said in this audio. If the audio is in Spanish, transcribe in Spanish. Do not add any commentary. Just the text."

            def _call_gemini():
                response = self.client.models.generate_content(
                    model=self.model_name,
                    contents=[myfile, prompt],
                    config=types.GenerateContentConfig(response_mime_type="text/plain")
                )
                return response.text.strip()

            text = await self._execute_with_retry(_call_gemini)
            print(f"🎤 [GEMINI] Transcripción: {text}")
            return text

        except Exception as e:
            print(f"Error transcribing audio: {e}")
            return ""

    async def process_bodeguero_audio(self, audio_file_path: str):
        # Para archivos, la lógica es más compleja porque el archivo se sube.
        # Por simplicidad, aquí intentamos con el modelo actual, si falla tocaría re-subir.
        try:
            myfile = self.client.files.upload(file=audio_file_path)
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

    async def analyze_product_image(self, image_bytes: bytes, mime_type: str = "image/jpeg", taxonomy: str = None) -> dict:
        """
        Analiza imagen de producto para extraer datos estructurados.
        Usa gemini-2.0-flash como solicitado.
        Incluye validación de seguridad y relevancia.
        """
        
        taxonomy_section = ""
        if taxonomy:
            taxonomy_section = f"""
            TAXONOMÍA VÁLIDA (Usa EXACTAMENTE estas opciones):
            {taxonomy}
            """
        else:
            # Fallback (updated with Golosinas just in case)
            taxonomy_section = """
            TAXONOMÍA VÁLIDA (Usa EXACTAMENTE estas opciones):
            - BEBIDAS: [Gaseosa, Agua, Cerveza, Energizante, Rehidratante, Jugo, Licor]
            - ABARROTES: [Arroz, Azúcar, Aceite, Fideos, Menestra, Conserva, Lácteos, Snack, Galleta, Condimento, Golosinas]
            - LIMPIEZA: [Detergente, Jabón, Lejía, Suavizante, Lavavajilla, Papel, Pañal, Toalla]
            - OTROS: [General]
            """

        prompt = f"""
        Actúa como un identificador experto de productos de bodega.
        Analiza esta imagen siguiendo estrictamente estos pasos:

        PASO 1: SEGURIDAD Y PRIVACIDAD (Critical Check)
        - Si detectas contenido sexual, de odio, violencia o personas reales (rostros, cuerpos completos), RECHAZA INMEDIATAMENTE.
        - EXCEPCIÓN: Manos sosteniendo un producto están permitidas.

        PASO 2: VALIDACIÓN DE PRODUCTO
        - El objeto principal DEBE ser un PRODCUTO COMERCIAL DE BODEGA en su empaque original (botella, lata, caja, bolsa) O productos frescos (frutas, verduras, huevos).
        - RECHAZA objetos sueltos personales irrelevantes (llaves, billetera, zapatos usados, mascotas, documentos, etc.).
        - Si la imagen es borrosa, oscura o no se distingue un producto -> RECHAZA.

        {taxonomy_section}

        PASO 3: EXTRACCIÓN DE DATOS (Solo si pasó Paso 1 y 2)
        - is_valid: true
        - "suggested_name": Nombre conciso en ESPAÑOL. (Marca + Tipo + Variedad/Sabor). Ej: "Gaseosa Coca Cola Zero", "Yogurt Gloria Fresa".
        - "brand": La marca principal detectada.
        - "category": Una de las llaves principales [Bebidas, Abarrotes, Limpieza, Otros].
        - "subcategory": Una de las opciones de la lista correspondiente a la categoría.
        - "volume": Contenido neto visible (ej: 500ml, 1kg). Si no visible, null.
        - "is_alcoholic": boolean.

        ESTRUCTURA DE RESPUESTA JSON (Obligatoria):
        {{
          "is_valid": boolean,
          "reason": string | null,
          "suggested_name": string | null,
          "brand": string | null,
          "category": string | null,
          "subcategory": string | null,
          "volume": string | null,
          "is_alcoholic": boolean,
          "attributes": {{
              "has_gas": boolean | null,
              "sugar_free": boolean | null,
              "lactose_free": boolean | null,
              "flavor": string | null
          }}
        }}
        """
        
        try:
            # Configuración de seguridad estricta
            safety_settings = [
                types.SafetySetting(
                    category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    threshold="BLOCK_LOW_AND_ABOVE"
                ),
                types.SafetySetting(
                    category="HARM_CATEGORY_HATE_SPEECH", 
                    threshold="BLOCK_LOW_AND_ABOVE"
                ),
                types.SafetySetting(
                    category="HARM_CATEGORY_HARASSMENT", 
                    threshold="BLOCK_LOW_AND_ABOVE"
                ),
                types.SafetySetting(
                    category="HARM_CATEGORY_DANGEROUS_CONTENT", 
                    threshold="BLOCK_LOW_AND_ABOVE"
                ),
            ]

            response = self.client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                            types.Part.from_text(text=prompt)
                        ]
                    )
                ],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                    safety_settings=safety_settings
                )
            )
            
            result = json.loads(response.text)
            
            # Normalización si devuelve lista
            if isinstance(result, list):
                result = result[0] if len(result) > 0 else {}

            # Asegurar campos mínimos
            return {
                "is_valid": result.get("is_valid", False),
                "reason": result.get("reason", "No se pudo analizar la imagen"),
                "suggested_name": result.get("suggested_name"),
                "brand": result.get("brand"),
                "category": result.get("category"),
                "subcategory": result.get("subcategory"),
                "volume": result.get("volume"),
                "is_alcoholic": result.get("is_alcoholic", False),
                "attributes": result.get("attributes", {})
            }

        except Exception as e:
            print(f"Error analyzing image: {e}")
            return {
                "is_valid": False,
                "reason": "Error al procesar la imagen (posible bloqueo de seguridad o error técnico).",
                "suggested_name": None,
                "brand": None,
                "category": None,
                "subcategory": None,
                "volume": None,
                "is_alcoholic": False,
                "attributes": {},
                "error": str(e)
            }

    async def analyze_bulk_products(self, image_bytes: bytes, mime_type: str = "image/jpeg", taxonomy: str = None) -> list:
        """
        Analiza imagen con MÚLTIPLES productos.
        Retorna lista de objetos detectados con nivel de confianza.
        """
        
        taxonomy_section = ""
        if taxonomy:
            taxonomy_section = f"""
            TAXONOMÍA REAL (USA ESTRICTAMENTE ÉSTAS OPCIONES):
            {taxonomy}
            
            SI EL PRODUCTO NO ENCAJA EN NINGUNA, USA "OTROS" / "General".
            NO INVENTES SUBCATEGORÍAS.
            """
        else:
             taxonomy_section = """
             TAXONOMÍA GENÉRICA:
             - BEBIDAS, ABARROTES, LIMPIEZA, OTROS.
             """

        prompt = f"""
        Actúa como un auditor de inventario experto.
        Analiza esta imagen y detecta TODOS los productos comerciales visibles.
        
        INSTRUCCIONES:
        1. Ignora objetos personales (celulares, llaves), mobiliario o personas.
        2. Para CADA producto identificado, extrae sus datos.
        3. Asigna un nivel de CONFIANZA:
           - "HIGH": Producto claro, texto legible, marca y variante inconfundibles.
           - "MEDIUM": Producto reconocible por forma/color, pero texto parcialmente oculto o borroso.
           - "LOW": Producto visible pero no se distingue marca o variante específica.

        {taxonomy_section}

        FORMATO DE RESPUESTA (JSON LIST):
        [
          {{
            "suggested_name": "Nombre completo en Español (Marca + Producto + Variante)",
            "category": "Nombre exacto de la Categoría (según taxonomía)",
            "subcategory": "Nombre exacto de la Subcategoría (según taxonomía) o null",
            "attributes": {{
                "brand": "Marca o null",
                "volume": "Contenido o null",
                "is_alcoholic": boolean
            }},
            "confidence": "HIGH" | "MEDIUM" | "LOW"
          }}
        ]
        
        Si no hay productos válidos, retorna [].
        """

        try:
            safety_settings = [
                types.SafetySetting(
                     category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                     threshold="BLOCK_LOW_AND_ABOVE"
                ),
                types.SafetySetting(
                     category="HARM_CATEGORY_HATE_SPEECH", 
                     threshold="BLOCK_LOW_AND_ABOVE"
                ),
                types.SafetySetting(
                     category="HARM_CATEGORY_HARASSMENT", 
                     threshold="BLOCK_LOW_AND_ABOVE"
                ),
                 types.SafetySetting(
                     category="HARM_CATEGORY_DANGEROUS_CONTENT", 
                     threshold="BLOCK_LOW_AND_ABOVE"
                ),
            ]

            response = self.client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                            types.Part.from_text(text=prompt)
                        ]
                    )
                ],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.2, # Un poco más alto para creatividad en detección múltiple
                    safety_settings=safety_settings
                )
            )

            result = json.loads(response.text)
            
            if isinstance(result, list):
                return result
            # Si Gemini devuelve un solo objeto por error, envolverlo
            if isinstance(result, dict):
                 return [result]
            
            return []

        except Exception as e:
            print(f"Error bulk analysis: {e}")
            return []


gemini_client = GeminiService()
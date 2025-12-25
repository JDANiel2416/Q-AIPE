import httpx
import logging
import os # <--- Importamos OS para leer variables de entorno
from dotenv import load_dotenv # <--- Para cargar el .env localmente

# Carga las variables del archivo .env
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ReniecService:
    BASE_URL = "https://apiperu.dev/api/dni"
    # Leemos el token del entorno. Si no existe, avisa.
    TOKEN = os.getenv("RENIEC_API_TOKEN")

    @staticmethod
    async def get_person_by_dni(dni: str):
        """
        Consulta la API real de apiperu.dev usando el token del .env
        """
        if not ReniecService.TOKEN:
            logger.error("CRITICAL: No se encontró RENIEC_API_TOKEN en el archivo .env")
            return None

        if not dni or len(dni) != 8:
            return None

        url = f"{ReniecService.BASE_URL}/{dni}?api_token={ReniecService.TOKEN}"
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url)
                
                if response.status_code == 200:
                    data = response.json()
                    
                    if data.get("success") and data.get("data"):
                        person = data["data"]
                        nombre_completo = f"{person['nombres']} {person['apellido_paterno']} {person['apellido_materno']}"
                        
                        return {
                            "dni": dni,
                            "full_name": nombre_completo,
                            "verification_source": "APIPERU_DEV"
                        }
                else:
                    logger.error(f"Error API Reniec: {response.status_code}")
                    
            except Exception as e:
                logger.error(f"Error conectando a Reniec: {e}")
                
        return None

    @staticmethod
    def obfuscate_name(full_name: str) -> str:
        """
        Censura el nombre: 'JOSÉ PEREZ' -> 'JO** PE***'
        """
        if not full_name:
            return ""
            
        parts = full_name.split()
        masked_parts = []
        for part in parts:
            if len(part) > 2:
                masked = part[:2] + "*" * (len(part) - 2)
            else:
                masked = part
            masked_parts.append(masked)
        return " ".join(masked_parts)

reniec_client = ReniecService()
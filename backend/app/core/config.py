from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # 1. Definimos qué variables esperamos (Python validará que existan)
    PROJECT_NAME: str
    API_V1_STR: str = "/api/v1"
    
    # Base de Datos
    DATABASE_URL: str

    # Reniec
    RENIEC_API_TOKEN: str
    
    # Inteligencia Artificial
    GEMINI_API_KEY: str

    # Configuración para leer el archivo .env automáticamente
    class Config:
        env_file = ".env"
        case_sensitive = True

# 2. Instanciamos la clase para usarla en todo el proyecto
settings = Settings()
import sys
import os
import pydantic
try:
    import pydantic_settings
    print(f"Pydantic Settings Version: {pydantic_settings.__version__}")
except ImportError:
    print("Pydantic Settings NOT INSTALLED")

print(f"Pydantic Version: {pydantic.VERSION}")

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from app.core.config import settings
    print(f"Settings loaded. DB URL: {settings.DATABASE_URL}")
except Exception as e:
    print(f"ERROR TYPE: {type(e)}")
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()

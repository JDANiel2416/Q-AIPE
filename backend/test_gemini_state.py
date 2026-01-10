import asyncio
import sys
import os

# Add the project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.gemini_service import gemini_client

async def test_state_updates():
    print("🚀 Testing Gemini State-Based Intent Memory...")
    
    # 1. Initial State
    state = []
    queries = [
        "Quiero una Inca Kola de 2 litros",
        "Agrega arroz costeño de 1 kilo",
        "No, mejor cambia la Inca Kola por una Coca Cola Zero",
        "Quita el arroz"
    ]
    
    for query in queries:
        print(f"\n💬 User: {query}")
        print(f"📦 Previous State: {state}")
        
        state = await gemini_client.interpret_search_intent(query, state)
        
        print(f"✨ New State: {state}")

if __name__ == "__main__":
    asyncio.run(test_state_updates())

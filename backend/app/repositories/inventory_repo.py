from sqlalchemy.orm import Session
from sqlalchemy import or_, cast, String, func
from app.models.tables import StoreInventory, MasterProduct, Bodega
from math import radians, cos, sin, asin, sqrt

class InventoryRepository:

    @staticmethod
    def search_products_smart(db: Session, keywords: list[str], user_lat: float, user_lon: float, max_dist_km: float = 5.0):
        """
        Busca productos por coincidencia parcial en nombre, categoría o sinónimos.
        Luego filtra por distancia.
        """
        if not keywords:
            return []

        # 1. Construimos la consulta base
        query = db.query(StoreInventory, MasterProduct, Bodega)\
            .join(MasterProduct, StoreInventory.product_id == MasterProduct.id)\
            .join(Bodega, StoreInventory.bodega_id == Bodega.id)\
            .filter(Bodega.manual_override == 'OPEN') # Solo bodegas abiertas

        # 2. Filtro Inteligente (OR)
        # Busca si ALGUNA de las palabras clave coincide con Nombre, Categoría o Sinónimos
        conditions = []
        for word in keywords:
            term = f"%{word}%" # Los % permiten buscar "Arroz" dentro de "Arroz Costeño"
            
            # Coincidencia en Nombre (Insensible a mayúsculas)
            conditions.append(MasterProduct.name.ilike(term))
            
            # Coincidencia en Categoría
            conditions.append(MasterProduct.category.ilike(term))
            
            # Coincidencia en Sinónimos (Truco: Convertimos el JSON a texto y buscamos dentro)
            # Esto busca "arroz" dentro de '["arroz", "kilo de arroz"]'
            conditions.append(cast(MasterProduct.synonyms, String).ilike(term))

        query = query.filter(or_(*conditions))

        # 3. Ejecutar consulta en BD
        raw_results = query.all()
        
        # 4. Filtrar por Distancia (Haversine) en Python
        # (Es más fácil y compatible que hacerlo en SQL puro sin extensiones geográficas)
        final_results = []
        
        for inv, prod, bodega in raw_results:
            dist = InventoryRepository.haversine(user_lat, user_lon, bodega.latitude, bodega.longitude)
            if dist <= max_dist_km:
                final_results.append((inv, prod, bodega))

        return final_results

    @staticmethod
    def haversine(lon1, lat1, lon2, lat2):
        """
        Calcula la distancia en Kilómetros entre dos puntos GPS
        """
        # Convertir grados a radianes
        lon1, lat1, lon2, lat2 = map(radians, [float(lon1), float(lat1), float(lon2), float(lat2)])

        # Fórmula de Haversine
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a)) 
        r = 6371 # Radio de la Tierra en km
        return c * r
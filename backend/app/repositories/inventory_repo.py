from sqlalchemy.orm import Session
from sqlalchemy import or_, cast, String, func
from app.models.tables import StoreInventory, MasterProduct, Bodega
from math import radians, cos, sin, asin, sqrt

class InventoryRepository:

    @staticmethod
    def search_products_smart(db: Session, keywords: list[str], user_lat: float, user_lon: float, max_dist_km: float = 3.0): # <--- CAMBIO: Radio aumentado a 3.0 km
        """
        Busca productos por coincidencia en nombre, categoría, sinónimos O ATRIBUTOS.
        Filtra en un radio de 3.0 km por defecto.
        """
        if not keywords:
            return []

        search_terms = set()
        for k in keywords:
            search_terms.add(k) 
            for word in k.split():
                if len(word) > 2: 
                    search_terms.add(word)
        
        # Consulta base: Bodegas abiertas o en automático (NULL)
        query = db.query(StoreInventory, MasterProduct, Bodega)\
            .join(MasterProduct, StoreInventory.product_id == MasterProduct.id)\
            .join(Bodega, StoreInventory.bodega_id == Bodega.id)\
            .filter(or_(
                Bodega.manual_override == 'OPEN',
                Bodega.manual_override.is_(None)
            ))

        conditions = []
        for term in search_terms:
            pattern = f"%{term}%" 
            conditions.append(MasterProduct.name.ilike(pattern))
            conditions.append(MasterProduct.category.ilike(pattern))
            conditions.append(cast(MasterProduct.synonyms, String).ilike(pattern))
            # Búsqueda en JSON (importante para encontrar "gas", "litro")
            conditions.append(cast(MasterProduct.attributes, String).ilike(pattern))

        if conditions:
            query = query.filter(or_(*conditions))

        raw_results = query.all()
        
        final_results = []
        for inv, prod, bodega in raw_results:
            dist = InventoryRepository.haversine(user_lat, user_lon, bodega.latitude, bodega.longitude)
            # Filtro de distancia
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
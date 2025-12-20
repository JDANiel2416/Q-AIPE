from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func, desc # <--- 1. AGREGAMOS and_ AQUÍ
from app.models.tables import MasterProduct, StoreInventory, Bodega, BodegaSchedule
from app.schemas.api_schemas import ProductItem
from datetime import datetime

class InventoryRepository:
    
    @staticmethod
    def search_products_smart(db: Session, keywords: list[str], user_lat: float, user_lon: float):
        now = datetime.now()
        current_day = now.weekday()
        current_time = now.time()

        query = db.query(StoreInventory, MasterProduct, Bodega)\
            .join(MasterProduct, StoreInventory.product_id == MasterProduct.id)\
            .join(Bodega, StoreInventory.bodega_id == Bodega.id)\
            .outerjoin(BodegaSchedule, Bodega.schedules)
            
        conditions = []
        for word in keywords:
            term = f"%{word.lower()}%"
            conditions.append(
                or_(
                    func.lower(MasterProduct.name).like(term),
                    func.array_to_string(MasterProduct.synonyms, ',').ilike(term) 
                )
            )
        
        if conditions:
            query = query.filter(or_(*conditions))

        # --- AQUÍ ESTABA EL ERROR ---
        # Usamos and_(...) para agrupar las condiciones del modo automático
        query = query.filter(
            or_(
                Bodega.manual_override == 'OPEN',
                and_(  # <--- 2. ESTO FALTABA: Envolver el bloque automático
                    Bodega.manual_override == None,
                    BodegaSchedule.day_of_week == current_day,
                    BodegaSchedule.open_time <= current_time,
                    BodegaSchedule.close_time >= current_time
                )
            )
        ).filter(Bodega.manual_override != 'CLOSED')

        results = query.all()
        return results

    @staticmethod
    def update_stock(db: Session, bodega_id: str, product_name_match: str, quantity: float):
        # Esta parte estaba bien, pero la copio para que tengas el archivo completo si quieres
        product = db.query(MasterProduct).filter(
            or_(
                MasterProduct.name.ilike(f"%{product_name_match}%"),
                func.array_to_string(MasterProduct.synonyms, ',').ilike(f"%{product_name_match}%")
            )
        ).first()

        if not product:
            return False, "Producto no encontrado en catálogo maestro"

        inventory_item = db.query(StoreInventory).filter(
            StoreInventory.bodega_id == bodega_id,
            StoreInventory.product_id == product.id
        ).first()

        if inventory_item:
            inventory_item.stock_quantity += quantity
            if inventory_item.stock_quantity < 0:
                inventory_item.stock_quantity = 0
        else:
            new_item = StoreInventory(
                bodega_id=bodega_id,
                product_id=product.id,
                stock_quantity=quantity,
                price=0.0 
            )
            db.add(new_item)

        db.commit()
        return True, f"Stock actualizado"
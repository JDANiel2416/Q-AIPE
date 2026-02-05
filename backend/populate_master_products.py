import requests
import sys
import os

# Add the backend directory to sys.path to allow importing from app
# We need 'backend' directory in sys.path so 'app' can be found as a top-level module
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models.tables import MasterProduct, Category, SubCategory

def fetch_openfoodfacts_products(country='peru', page_size=100, pages=5):
    """
    Fetches products from OpenFoodFacts API.
    """
    base_url = "https://world.openfoodfacts.org/cgi/search.pl"
    products = []

    for page in range(1, pages + 1):
        print(f"Fetching page {page}...")
        params = {
            "action": "process",
            "tagtype_0": "countries",
            "tag_contains_0": "contains",
            "tag_0": country,
            "sort_by": "popularity_key",
            "page_size": page_size,
            "page": page,
            "json": 1
        }
        
        try:
            response = requests.get(base_url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if 'products' in data:
                products.extend(data['products'])
            else:
                print(f"No products found on page {page}.")
                break
                
        except Exception as e:
            print(f"Error fetching page {page}: {e}")
            break
            
    return products

def get_category_from_tags(product_data):
    """
    Maps OpenFoodFacts tags to our simple categories.
    """
    categories_tags = product_data.get('categories_tags', [])
    
    # Simple keyword mapping
    keyword_map = {
        'beverages': 'Bebidas',
        'drinks': 'Bebidas',
        'sodas': 'Bebidas',
        'waters': 'Bebidas',
        'juices': 'Bebidas',
        'snacks': 'Snacks',
        'chips': 'Snacks',
        'biscuits': 'Snacks',
        'chocolates': 'Snacks',
        'dairies': 'Lácteos',
        'milks': 'Lácteos',
        'yogurts': 'Lácteos',
        'cheeses': 'Lácteos',
        'meats': 'Carnes',
        'chicken': 'Carnes',
        'fruits': 'Frutas y Verduras',
        'vegetables': 'Frutas y Verduras',
        'cereals': 'Desayuno',
        'breads': 'Panadería',
        'cleaning': 'Limpieza',
        'hygiene': 'Cuidado Personal',
        'alcohol': 'Licores',
        'beers': 'Licores',
        'wines': 'Licores'
    }

    for tag in categories_tags:
        tag_lower = tag.lower()
        for key, value in keyword_map.items():
            if key in tag_lower:
                return value
                
    # Fallback based on product name if tags fail
    name = product_data.get('product_name', '').lower()
    if 'gaseosa' in name or 'agua' in name or 'cerveza' in name or 'bebida' in name:
        return 'Bebidas'
    if 'arroz' in name or 'fideo' in name or 'azucar' in name or 'aceite' in name:
        return 'Abarrotes'
        
    return 'Otros'

def populate_master_products():
    db = SessionLocal()
    try:
        print("Starting data fetch from OpenFoodFacts (Peru)...")
        # Fetch generic popular products globally if Peru has few, but let's stick to Peru first
        # Maybe fetch 2 pages of Peru and 1 page of global popular for variety?
        # User asked for "Peru or global popular". Let's do Peru first.
        products = fetch_openfoodfacts_products(country='peru', pages=2)
        
        # Also fetch some global Coca Cola / snacks just in case
        print("Fetching some global popular products...")
        global_products = fetch_openfoodfacts_products(country='world', pages=1) # popularity sorted
        products.extend(global_products)
        
        print(f"Total products fetched: {len(products)}")
        
        inserted_count = 0
        skipped_count = 0
        
        # Cache existing names to minimize DB queries
        existing_names = set(
            name for name, in db.query(MasterProduct.name).all()
        )
        
        for p in products:
            product_name = p.get('product_name')
            if not product_name:
                continue
                
            # Cleanup name
            product_name = product_name.strip()
            
            # Deduplication
            if product_name in existing_names:
                skipped_count += 1
                continue
            
            # Get Image URL
            image_url = p.get('image_front_url') or p.get('image_url')
            if not image_url:
                # Try getting small url
                image_url = p.get('image_front_small_url')
            
            # Get Category
            category = get_category_from_tags(p)
            
            # Get Attributes (Brand, Quantity)
            attributes = {}
            if 'brands' in p and p['brands']:
                attributes['marca'] = p['brands'].split(',')[0]
            if 'quantity' in p and p['quantity']:
                attributes['contenido'] = p['quantity']
                
            # Create MasterProduct
            new_product = MasterProduct(
                name=product_name,
                category=category,
                image_url=image_url,
                attributes=attributes,
                default_unit="UND", # Default
                synonyms=[] 
            )
            
            db.add(new_product)
            existing_names.add(product_name)
            inserted_count += 1
            
        db.commit()
        print(f"Process complete!")
        print(f"Inserted: {inserted_count}")
        print(f"Skipped (Duplicates): {skipped_count}")

    except Exception as e:
        print(f"An error occurred: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    populate_master_products()

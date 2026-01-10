import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class BodegueroScreen extends StatefulWidget {
  const BodegueroScreen({super.key});

  @override
  State<BodegueroScreen> createState() => _BodegueroScreenState();
}

class _BodegueroScreenState extends State<BodegueroScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _userId = "";
  
  // Búsqueda
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  
  // Tab Controller
  late TabController _tabController;
  
  // Categorías
  final List<String> _categories = ['Bebidas', 'Abarrotes', 'Limpieza', 'Otros'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      // Update UI when tab changes (including swipe)
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Obtener productos de una categoría específica
  List<dynamic> _getProductsForCategory(String category) {
    var filtered = _products.where((p) => (p['category'] ?? "Otros") == category).toList();
    
    // Aplicar búsqueda si existe
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => 
        p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Ordenar alfabéticamente
    filtered.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    
    return filtered;
  }
  
  // Contar productos por categoría
  int _getProductCount(String category) {
    return _products.where((p) => (p['category'] ?? "Otros") == category).length;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final uid = await SessionService().getUserId();
    if (uid != null) {
      _userId = uid;
      final data = await _api.getMyInventory(uid);
      setState(() {
        // Handle new response format: {bodega_name: "X", products: [...]}
        if (data is Map && data['products'] != null) {
          _products = data['products'];
        } else if (data is List) {
          _products = data; // Fallback for old format
        } else {
          _products = [];
        }
        _isLoading = false;
      });
    }
  }

  void _toggleProduct(Map<String, dynamic> product, bool value) async {
    // Optimistic Update
    setState(() {
      product['in_stock'] = value;
    });

    final success = await _api.toggleStock(_userId, product['product_id'], value);
    
    if (!success) {
      // Revertir
      setState(() {
        product['in_stock'] = !value;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _navigateToAddProduct() async {
    final bool? result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const AddProductScreen())
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          const MinimalistBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(),
                
                // Tabs
                if (!_isLoading)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (index) => setState(() {
                        _searchQuery = "";
                        _searchCtrl.clear();
                      }),
                      indicator: BoxDecoration(
                        color: const Color(0xFF00D9FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white.withOpacity(0.6),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: _categories.map((cat) {
                        final count = _getProductCount(cat);
                        return Tab(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(cat),
                              const SizedBox(height: 2),
                              Text(
                                '($count)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.normal,
                                  color: _tabController.index == _categories.indexOf(cat)
                                      ? Colors.black54
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                
                // Barra de búsqueda
                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Buscar en ${_categories[_tabController.index]}...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00D9FF)),
                        filled: true,
                        fillColor: const Color(0xFF1A1F2E).withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                      ),
                    ),
                  ),
                
                // Lista de productos
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
                      : TabBarView(
                          controller: _tabController,
                          children: _categories.map((category) {
                            return _buildCategoryView(category);
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProduct,
        label: const Text("Agregar Producto", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryView(String category) {
    final products = _getProductsForCategory(category);
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D9FF).withOpacity(0.15),
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF00D9FF)),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty 
                  ? "No tienes productos en $category"
                  : "No se encontraron productos",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? "¡Agrega tu primer producto!"
                  : "Intenta con otra búsqueda",
              style: const TextStyle(color: Color(0xFFA0A8B8), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final prod = products[i];
        final bool inStock = prod['in_stock'];
        
        return InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProductScreen(product: prod),
              ),
            );
            // Reload data if changes were made
            if (result == true) {
              _loadData();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: inStock 
                          ? const Color(0xFF00D9FF).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      inStock ? Icons.check_circle : Icons.remove_circle_outline,
                      color: inStock ? const Color(0xFF00D9FF) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "S/ ${prod['price'].toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Color(0xFF00D9FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Stock: ${prod['stock']}",
                              style: const TextStyle(
                                color: Color(0xFFA0A8B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: inStock,
                    onChanged: (val) => _toggleProduct(prod, val),
                    activeColor: const Color(0xFF00D9FF),
                    activeTrackColor: const Color(0xFF00D9FF).withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            ),
          ),
          const Column(
            children: [
              Text(
                "Mi Inventario",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "Gestión de Productos",
                style: TextStyle(color: Color(0xFFA0A8B8), fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.store, color: Color(0xFF00D9FF), size: 20),
          ),
        ],
      ),
    );
  }
}

// --- FONDO MINIMALISTA ESTÁTICO ---
class MinimalistBackground extends StatelessWidget {
  const MinimalistBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E1A),
            Color(0xFF0F1419),
            Color(0xFF0A0E1A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
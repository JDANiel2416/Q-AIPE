import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'bodeguero_colors.dart';

class ManualSaleScreen extends StatefulWidget {
  const ManualSaleScreen({super.key});

  @override
  State<ManualSaleScreen> createState() => _ManualSaleScreenState();
}

class _ManualSaleScreenState extends State<ManualSaleScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _userId = "";

  // Búsqueda
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  // Carrito: ProductID -> Cantidad
  final Map<int, int> _cart = {};
  // Mapa auxiliar para acceso rápido: ProductID -> Data
  final Map<int, dynamic> _productMap = {};

  // Categorías
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  late final PageController _pageController;
  int _currentTabIndex = 0;
  late final ValueNotifier<double> _pillPositionNotifier;

  Timer? _refreshTimer;
  String _bodegaId = "";

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pillPositionNotifier = ValueNotifier<double>(0.0);
    _pageController.addListener(_handlePageScroll);
    _loadCategories();

    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(
      Duration(seconds: 5),
      (_) => _loadData(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    _pillPositionNotifier.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    _pillPositionNotifier.value = _pageController.page ?? 0.0;
    final newIndex = (_pageController.page ?? 0).round();
    if (newIndex != _currentTabIndex) {
      setState(() => _currentTabIndex = newIndex);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.getCategories();
      if (!mounted) return;

      setState(() {
        if (cats.isNotEmpty) {
          _categories = cats.map((cat) {
            IconData icon = Icons.category_outlined;
            final n = cat.name.toLowerCase();
            if (n.contains('bebida'))
              icon = Icons.local_drink_outlined;
            else if (n.contains('abarrote'))
              icon = Icons.shopping_basket_outlined;
            else if (n.contains('limpieza'))
              icon = Icons.cleaning_services_outlined;
            else if (n.contains('fruta'))
              icon = Icons.eco_outlined;
            else if (n.contains('pan'))
              icon = Icons.breakfast_dining_outlined;
            else if (n.contains('carne'))
              icon = Icons.set_meal_outlined;
            else if (n.contains('mascota'))
              icon = Icons.pets;

            return {'name': cat.name, 'icon': icon, 'id': cat.id};
          }).toList();
        } else {
          _categories = [
            {'name': 'Bebidas', 'icon': Icons.local_drink_outlined},
            {'name': 'Abarrotes', 'icon': Icons.shopping_basket_outlined},
            {'name': 'Limpieza', 'icon': Icons.cleaning_services_outlined},
            {'name': 'Otros', 'icon': Icons.category_outlined},
          ];
        }
        _loadingCategories = false;
      });
      _loadData();
    } catch (e) {
      print("Error loading categories: $e");
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final uid = await SessionService().getUserId();
      if (uid != null) {
        _userId = uid;
        final data = await _api.getMyInventory(uid);
        if (!mounted) return;

        setState(() {
          if (data is Map) {
            if (data['products'] != null) _products = data['products'];
            if (data['bodega_id'] != null)
              _bodegaId = data['bodega_id']; // Save bodega_id
          } else if (data is List) {
            _products = data;
          } else {
            _products = [];
          }

          // Llenar mapa auxiliar
          for (var p in _products) {
            _productMap[p['product_id']] = p;
          }
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGICA CARRITO ---

  void _addToCart(dynamic product) {
    if (!product['in_stock'])
      return; // No agregar si no hay stock (aunque se filtre visualmente)

    // Validar stock disponible
    final currentQty = _cart[product['product_id']] ?? 0;
    if (currentQty >= product['stock']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stock máximo alcanzado para este producto")),
      );
      return;
    }

    setState(() {
      int id = product['product_id'];
      _cart[id] = (currentQty) + 1;
    });
  }

  void _removeFromCart(dynamic product) {
    setState(() {
      int id = product['product_id'];
      if (_cart.containsKey(id) && _cart[id]! > 0) {
        _cart[id] = _cart[id]! - 1;
        if (_cart[id] == 0) _cart.remove(id);
      }
    });
  }

  double _getCartTotal() {
    double total = 0;
    _cart.forEach((id, qty) {
      final product = _productMap[id];
      if (product != null) {
        total += (product['price'] ?? 0.0) * qty;
      }
    });
    return total;
  }

  Future<void> _processSale() async {
    if (_cart.isEmpty) return;

    // Preparar items
    List<dynamic> items = [];
    _cart.forEach((id, qty) {
      final product = _productMap[id];
      items.add({
        "productId": id,
        "name": product['name'],
        "requestedQuantity": qty,
        "price": product['price'],
      });
    });

    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirmar Venta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total a cobrar: S/ ${_getCartTotal().toStringAsFixed(2)}"),
            const SizedBox(height: 10),
            Text("${items.length} productos diferentes."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: Text("Cobrar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Loading...
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    // Enviar al backend
    // Usamos el ID de la bodega actual. Como no lo tenemos directo en state, lo obtenemos del user
    // pero `createReservation` pide `bodegaId`.
    // Una opción rápida es llamar a `getProfile` para obtener `bodega_id` o pasarlo desde Dashboard.
    // O mejor, modificar `createReservation` para que acepte `bodega_id` nulo y el backend lo busque por `user_id` si es manual.
    // Pero el backend actual REQUIERE `bodega_id`.
    // Voy a obtener el perfil primero o guardarlo en `_loadData` si es que `getMyInventory` devuelve `bodega_id`.

    // Debug: check bodegaId
    print(
      '[DEBUG] _processSale called. bodegaId: $_bodegaId, userId: $_userId, items: ${items.length}',
    );

    if (_bodegaId.isEmpty) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: No se pudo obtener la bodega. Intenta recargar.",
          ),
          backgroundColor: BColors.error,
        ),
      );
      return;
    }

    try {
      final result = await _api.createReservation(
        _userId,
        _bodegaId,
        items,
        isManual: true,
      );

      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        // Éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Venta registrada exitosamente"),
            backgroundColor: BColors.success,
          ),
        );
        setState(() {
          _cart.clear();
        });
        _loadData(); // Recargar stock
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Error al registrar venta"),
            backgroundColor: BColors.error,
          ),
        );
      }
    } catch (e) {
      print('[DEBUG] Error in _processSale: $e');
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: BColors.error,
        ),
      );
    }
  }

  // ... (UI Components similar to product_management)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      appBar: AppBar(
        title: Text(
          "Venta Manual",
          style: TextStyle(
            color: BColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: BColors.primary(context)),
      ),
      body: Column(
        children: [
          if (!_isLoading && !_loadingCategories && _categories.isNotEmpty)
            _buildGlassCategoryBar(),

          if (!_isLoading) _buildSearchBar(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : PageView(
                    controller: _pageController,
                    children: _categories
                        .map((c) => _buildCategoryView(c['name']))
                        .toList(),
                  ),
          ),

          // Bottom Bar Carrrito
          if (_cart.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildGlassCategoryBar() {
    // (Mismo código que product_management_screen, simplificado para brevedad si es posible, o copiar y pegar)
    // Copiaré la lógica esencial para que funcione igual.
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (ctx, index) {
          final cat = _categories[index];
          final isSelected = index == _currentTabIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? BColors.primary(context)
                    : BColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : BColors.border(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'],
                    color: isSelected
                        ? Colors.white
                        : BColors.textSecondary(context),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    cat['name'],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : BColors.textSecondary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Buscar producto...",
          prefixIcon: Icon(Icons.search),
          filled: true,
          fillColor: BColors.surface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView(String category) {
    // Filtrar
    var filtered = _products
        .where((p) => (p['category'] ?? "Otros") == category)
        .toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) => p['name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    if (filtered.isEmpty) return Center(child: Text("No hay productos"));

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final prod = filtered[i];
        final cartQty = _cart[prod['product_id']] ?? 0;
        final hasStock =
            prod['in_stock']; // Usamos in_stock como indicador de disponibilidad

        return Card(
          elevation: 0,
          color: BColors.surface(context),
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(12),
            title: Text(
              prod['name'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "S/ ${prod['price'].toStringAsFixed(2)}  |  Stock: ${prod['stock']}",
              style: TextStyle(
                color: hasStock
                    ? BColors.textSecondary(context)
                    : BColors.error,
              ),
            ),
            trailing: hasStock
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cartQty > 0)
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: BColors.error,
                          ),
                          onPressed: () => _removeFromCart(prod),
                        ),
                      if (cartQty > 0)
                        Text(
                          "$cartQty",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: BColors.primary(context),
                        ),
                        onPressed: () => _addToCart(prod),
                      ),
                    ],
                  )
                : Chip(
                    label: Text(
                      "Agotado",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    backgroundColor: BColors.textMuted(context),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total",
                style: TextStyle(color: BColors.textSecondary(context)),
              ),
              Text(
                "S/ ${_getCartTotal().toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: BColors.textPrimary(context),
                ),
              ),
            ],
          ),
          Spacer(),
          ElevatedButton(
            onPressed: _processSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: BColors.primary(context),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "COBRAR (${_cart.length})",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

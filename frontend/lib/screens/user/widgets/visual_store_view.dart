import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'dart:ui';
import '../home_colors.dart';
import '../../../services/api_service.dart';

class VisualStoreView extends StatefulWidget {
  final Point userLocation;
  final ApiService apiService;
  final Function(String) onSendToChat;

  const VisualStoreView({
    super.key,
    required this.userLocation,
    required this.apiService,
    required this.onSendToChat,
  });

  @override
  State<VisualStoreView> createState() => _VisualStoreViewState();
}

class _VisualStoreViewState extends State<VisualStoreView> {
  // Estado
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;

  // Controladores Liquid
  late final PageController _pageController;
  late final ValueNotifier<double> _pillPositionNotifier;
  int _currentTabIndex = 0;
  bool _isDraggingBar = false;

  // Carrito: inventory_id -> Quantity
  // Carrito: key -> Quantity
  final Map<String, int> _cart = {};
  // Detalles para resumen: key -> Item
  final Map<String, Map<String, dynamic>> _cartDetails = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pillPositionNotifier = ValueNotifier<double>(0.0);
    _pageController.addListener(_handlePageScroll);
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _pillPositionNotifier.dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    final pageValue = _pageController.page ?? 0.0;
    if (!_isDraggingBar) {
      _pillPositionNotifier.value = pageValue;
    }
    final newIndex = pageValue.round();
    if (newIndex != _currentTabIndex) {
      setState(() => _currentTabIndex = newIndex);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final results = await widget.apiService.getSearchCategories();
      if (results.isNotEmpty) {
        setState(() {
          _categories = results
              .map((c) => {"name": c['name'], "icon": _mapIcon(c['icon_name'])})
              .toList();
          _loadingCategories = false;
        });
      } else {
        _useDefaultCategories();
      }
    } catch (e) {
      print("Error loading categories: $e");
      _useDefaultCategories();
    }
  }

  void _useDefaultCategories() {
    setState(() {
      _categories = [
        {"name": "Bebidas", "icon": Icons.local_drink},
        {"name": "Abarrotes", "icon": Icons.shopping_basket},
        {"name": "Limpieza", "icon": Icons.cleaning_services},
      ];
      _loadingCategories = false;
    });
  }

  IconData _mapIcon(String? iconName) {
    switch (iconName) {
      case 'local_drink':
        return Icons.local_drink;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'fastfood':
        return Icons.fastfood;
      case 'face':
        return Icons.face;
      case 'egg_alt':
      case 'egg':
        return Icons.egg;
      case 'category':
        return Icons.category;
      default:
        return Icons.store;
    }
  }

  // Floating Button para Carrito
  @override
  Widget build(BuildContext context) {
    // Wrapper para añadir el botón flotante
    return Stack(
      children: [
        _buildContent(context),
        if (_cart.isNotEmpty) _buildCheckoutButton(),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loadingCategories) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 110),
        _buildLiquidCategoryBar(),
        const SizedBox(height: 16),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return _CategoryProductPage(
                category: _categories[index]['name'],
                apiService: widget.apiService,
                userLocation: widget.userLocation,
                cart: _cart,
                onAddToCart: (item) {
                  setState(() {
                    final key = "${item['product_id']}_${item['bodega_id']}";
                    _cart[key] = (_cart[key] ?? 0) + 1;
                    _cartDetails[key] = item;
                  });
                },
                onRemoveFromCart: (item) {
                  setState(() {
                    final key = "${item['product_id']}_${item['bodega_id']}";
                    if ((_cart[key] ?? 0) > 0) {
                      _cart[key] = _cart[key]! - 1;
                      if (_cart[key] == 0) {
                        _cart.remove(key);
                        _cartDetails.remove(key);
                      }
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton() {
    final totalItems = _cart.values.fold(0, (sum, qty) => sum + qty);
    final totalPrice = _cart.entries.fold(0.0, (sum, entry) {
      final item = _cartDetails[entry.key];
      return sum + (entry.value * (item?['price'] ?? 0));
    });

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: _processOrder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: HomeColors.primary(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: HomeColors.primary(context).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "$totalItems",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Ver Resumen",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "S/ ${totalPrice.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                "Enviar a IA",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _processOrder() {
    if (_cart.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("Quiero confirmar el siguiente pedido:");

    _cart.forEach((id, qty) {
      final item = _cartDetails[id];
      if (item != null) {
        buffer.writeln(
          "- $qty x ${item['product_name']} (Bodega: ${item['bodega_name']}) - S/ ${(item['price'] * qty).toStringAsFixed(2)}",
        );
      }
    });

    buffer.writeln("\nPor favor, genera mi ticket de reservación.");

    widget.onSendToChat(buffer.toString());

    // Limpiar carrito opcionalmente o esperar confirmación?
    // Mejor mantenerlo hasta que el usuario confirme, pero por ahora lo limpiamos para evitar duplicados si vuelve
    setState(() {
      _cart.clear();
      _cartDetails.clear();
    });
  }

  Widget _buildLiquidCategoryBar() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: HomeColors.surface(context).withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowLight(context),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double itemWidth = totalWidth / _categories.length;

                return GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _isDraggingBar = true),
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    if (delta != 0 && _pageController.hasClients) {
                      final double deltaIndex = delta / itemWidth;
                      double targetPage =
                          _pillPositionNotifier.value + deltaIndex;
                      targetPage = targetPage.clamp(
                        0.0,
                        _categories.length - 1.0,
                      );
                      _pillPositionNotifier.value = targetPage;

                      final double viewportWidth =
                          _pageController.position.viewportDimension;
                      _pageController.jumpTo(targetPage * viewportWidth);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() => _isDraggingBar = false);
                    final int finalIndex = _pillPositionNotifier.value.round();
                    _pageController.animateToPage(
                      finalIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Stack(
                    children: [
                      // Píldora
                      ValueListenableBuilder<double>(
                        valueListenable: _pillPositionNotifier,
                        builder: (context, position, child) {
                          final leftOffset = position * itemWidth;
                          return Positioned(
                            left: leftOffset,
                            top: 0,
                            bottom: 0,
                            width: itemWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: HomeColors.primary(context),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeColors.primary(
                                      context,
                                    ).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Textos/Iconos
                      Row(
                        children: _categories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final cat = entry.value;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _pillPositionNotifier,
                                builder: (context, position, child) {
                                  final isActive = position.round() == index;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData,
                                        size: 20,
                                        color: isActive
                                            ? Colors.white
                                            : HomeColors.textSecondary(context),
                                      ),
                                      Text(
                                        cat['name'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isActive
                                              ? Colors.white
                                              : HomeColors.textSecondary(
                                                  context,
                                                ),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryProductPage extends StatefulWidget {
  final String category;
  final ApiService apiService;
  final Point userLocation;
  final Map<String, int> cart;
  final Function(Map<String, dynamic>) onAddToCart;
  final Function(Map<String, dynamic>) onRemoveFromCart;

  const _CategoryProductPage({
    required this.category,
    required this.apiService,
    required this.userLocation,
    required this.cart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  State<_CategoryProductPage> createState() => _CategoryProductPageState();
}

class _CategoryProductPageState extends State<_CategoryProductPage>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _products = [];
  List<String> _bodegas = [];
  String? _selectedBodega;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true; // Mantener estado al deslizar

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final results = await widget.apiService.getVisualStoreProducts(
        category: widget.category,
        lat: widget.userLocation.latitude,
        lon: widget.userLocation.longitude,
      );

      // Extraer bodegas únicas
      final bodegasSet = results.map((e) => e['bodega_name'] as String).toSet();

      if (mounted) {
        setState(() {
          _products = results;
          _bodegas = bodegasSet.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keepAlive

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: HomeColors.primary(context)),
      );
    }
    if (_hasError) {
      return const Center(child: Text("Error cargando productos"));
    }
    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    // Filtrar productos
    final filteredProducts = _selectedBodega == null
        ? _products
        : _products.where((p) => p['bodega_name'] == _selectedBodega).toList();

    return Column(
      children: [
        // Cinta de Bodegas
        _buildBodegaRibbon(),

        const SizedBox(height: 8),

        // Lista de Productos
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(child: Text("No hay productos en esta bodega"))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _buildVisualProductCard(filteredProducts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            color: HomeColors.textMuted(context),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            "No hay productos cercanos",
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBodegaRibbon() {
    if (_bodegas.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildBodegaChip(null, "Todas"),
          ..._bodegas.map((b) => _buildBodegaChip(b, b)),
        ],
      ),
    );
  }

  Widget _buildBodegaChip(String? bodegaValue, String label) {
    final isSelected = _selectedBodega == bodegaValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedBodega = bodegaValue),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? HomeColors.primary(context)
              : HomeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : HomeColors.border(context),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: HomeColors.primary(context).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : HomeColors.textPrimary(context),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualProductCard(Map<String, dynamic> item) {
    final key = "${item['product_id']}_${item['bodega_id']}";
    final qty = widget.cart[key] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.border(context).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowLight(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: HomeColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
              image: item['image_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['image_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['image_url'] == null
                ? Icon(Icons.shopping_bag, color: HomeColors.textMuted(context))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'Producto',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HomeColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.store,
                      size: 12,
                      color: HomeColors.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['bodega_name'] ?? 'Bodega',
                        style: TextStyle(
                          color: HomeColors.textSecondary(context),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['distance_meters'] != null
                      ? "${item['distance_meters']} m"
                      : "",
                  style: TextStyle(
                    color: HomeColors.primary(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "S/ ${item['price']}",
                style: TextStyle(
                  color: HomeColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (qty == 0)
                GestureDetector(
                  onTap: () => widget.onAddToCart(item),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HomeColors.primary(context).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: HomeColors.primary(context),
                      size: 20,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomeColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HomeColors.border(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => widget.onRemoveFromCart(item),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "$qty",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HomeColors.textPrimary(context),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onAddToCart(item),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: HomeColors.primary(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

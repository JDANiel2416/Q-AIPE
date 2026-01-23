import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import '../common/login_screen.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

// =============================================================================
// PALETA DE COLORES - TEMA CLARO MODERNO
// =============================================================================
class AppColors {
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color primary = Color(0xFF0062FF);
  static const Color primaryLight = Color(0xFFE6F0FF);
  static const Color primaryDark = Color(0xFF0052D6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
}

class BodegueroScreen extends StatefulWidget {
  final bool isEmbedded;
  
  const BodegueroScreen({super.key, this.isEmbedded = false});

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
  
  // Tab Controller eliminado
  // late TabController _tabController; -> Reemplazado por PageController
  
  // Controlador de páginas para sincronización perfecta
  late final PageController _pageController;
  
  // Categorías con iconos
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Bebidas', 'icon': Icons.local_drink_outlined},
    {'name': 'Abarrotes', 'icon': Icons.shopping_basket_outlined},
    {'name': 'Limpieza', 'icon': Icons.cleaning_services_outlined},
    {'name': 'Otros', 'icon': Icons.category_outlined},
  ];


  
  // Índice actual del tab para sincronizar UI en tiempo real
  int _currentTabIndex = 0;
  // Notificador para posición continua de la píldora
  late final ValueNotifier<double> _pillPositionNotifier;
  // Estado para arrastre directo en la barra
  bool _isDraggingBar = false;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    _pageController = PageController();
    _pillPositionNotifier = ValueNotifier<double>(0.0);
    // Escuchar cambios de scroll en tiempo real
    _pageController.addListener(_handlePageScroll);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _pillPositionNotifier.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Manejar scroll de página para actualización en tiempo real
  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    
    final pageValue = _pageController.page ?? 0.0;
    
    // Sincronizar el notificador si no estamos arrastrando la BARRA manualmente
    if (!_isDraggingBar) {
      _pillPositionNotifier.value = pageValue;
    }

    final newIndex = pageValue.round();
    // Solo actualizamos el estado si el índice entero cambia (para UI estática)
    if (newIndex != _currentTabIndex) {
      setState(() {
        _currentTabIndex = newIndex;
      });
    }
  }

  List<dynamic> _getProductsForCategory(String category) {
    var filtered = _products.where((p) => (p['category'] ?? "Otros") == category).toList();
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => 
        p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    filtered.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    
    return filtered;
  }
  
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
        if (data is Map && data['products'] != null) {
          _products = data['products'];
        } else if (data is List) {
          _products = data;
        } else {
          _products = [];
        }
        _isLoading = false;
      });
    }
  }

  void _toggleProduct(Map<String, dynamic> product, bool value) async {
    setState(() {
      product['in_stock'] = value;
    });

    final success = await _api.toggleStock(_userId, product['product_id'], value);
    
    if (!success) {
      setState(() {
        product['in_stock'] = !value;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error de conexión"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            
            // Glassmorphism Category Bar
            if (!_isLoading)
              _buildGlassCategoryBar(),
            
            // Barra de búsqueda
            if (!_isLoading)
              _buildSearchBar(),
            
            // Lista de productos
            // Lista de productos (PageView para control total del scroll)
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text("Cargando productos...", style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : PageView(
                      controller: _pageController,
                      children: _categories.map((category) {
                        return _buildCategoryView(category['name']);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: widget.isEmbedded ? 100.0 : 0.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _navigateToAddProduct,
            label: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back button - only show when NOT embedded
          if (!widget.isEmbedded) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: AppColors.primary, size: 18),
              ),
            ),
            const SizedBox(width: 16),
          ],
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mi Inventario",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  "${_products.length} productos",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Stats icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCategoryBar() {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(35),
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
                  onHorizontalDragStart: (_) {
                    setState(() {
                      _isDraggingBar = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    if (delta != 0 && _pageController.hasClients) {
                      // 1. Calcular nueva posición de la píldora (lógica visual)
                      final double deltaIndex = delta / itemWidth; // Drag derecho es positivo
                      // Importante: PageView funciona al revés que la intuición visual directa en drag?
                      // Normal: swipe left (delta negativo) -> avanza pagina (index aumenta).
                      // Drag pildora derecha (delta positivo) -> queremos avanzar pagina (index aumenta).
                      // Pero el scroll offset del PageView: aumentar offset -> avanza pagina.
                      
                      double targetPage = _pillPositionNotifier.value + deltaIndex;
                      targetPage = targetPage.clamp(0.0, _categories.length - 1.0);
                      
                      // Actualizar UI de la píldora inmediatamente
                      _pillPositionNotifier.value = targetPage;
                      
                      // 2. Mover el PageView píxel por píxel (jumpTo)
                      // page = pixels / viewportDimension
                      // pixels = page * viewportDimension
                      final double viewportWidth = _pageController.position.viewportDimension;
                      final double targetPixels = targetPage * viewportWidth;
                      
                      _pageController.jumpTo(targetPixels);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _isDraggingBar = false;
                    });
                    // Forzar snap al índice más cercano usando la animación nativa del PageView
                    final int finalIndex = _pillPositionNotifier.value.round();
                    _pageController.animateToPage(
                      finalIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Stack(
                    children: [
                      // Indicador deslizante "Liquid" - Posicionamiento absoluto mediante ValueNotifier
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
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Items transparentes encima
                      Row(
                        children: _categories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _searchQuery = "";
                                  _searchCtrl.clear();
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _pillPositionNotifier,
                                builder: (context, position, child) {
                                  // Lógica de resaltado: cuando más del 50% de la píldora está encima (redondeo)
                                  final isActive = position.round() == index;
                                  final opacity = isActive ? 1.0 : 0.7;
                                  final color = isActive ? Colors.white : AppColors.textSecondary;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        category['icon'],
                                        size: 22,
                                        color: color,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        category['name'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                          color: color,
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "Buscar en ${_categories[_currentTabIndex]['name']}...",
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppColors.textMuted, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
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
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
              ),
              child: Icon(Icons.inventory_2_outlined, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty 
                  ? "No tienes productos en $category"
                  : "No se encontraron productos",
              style: TextStyle(
                color: AppColors.textPrimary, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? "¡Agrega tu primer producto!"
                  : "Intenta con otra búsqueda",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToAddProduct,
                icon: const Icon(Icons.add),
                label: const Text("Agregar Producto"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: widget.isEmbedded ? 120 : 8,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final prod = products[i];
        final bool inStock = prod['in_stock'];
        
        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProductScreen(product: prod),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: inStock ? AppColors.border : AppColors.textMuted.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container with status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: inStock 
                          ? LinearGradient(
                              colors: [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0.05)],
                            )
                          : null,
                      color: inStock ? null : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      inStock ? Icons.check_circle : Icons.pause_circle_outline,
                      color: inStock ? AppColors.success : AppColors.textMuted,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod['name'],
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "S/ ${prod['price'].toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              "${prod['stock']} uds",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Toggle switch with label
                  Column(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: inStock,
                          onChanged: (val) => _toggleProduct(prod, val),
                          activeColor: AppColors.success,
                          activeTrackColor: AppColors.success.withOpacity(0.3),
                          inactiveThumbColor: AppColors.textMuted,
                          inactiveTrackColor: AppColors.surfaceVariant,
                        ),
                      ),
                      Text(
                        inStock ? "En stock" : "Pausado",
                        style: TextStyle(
                          fontSize: 10,
                          color: inStock ? AppColors.success : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
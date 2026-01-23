import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:ui';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../common/login_screen.dart';
import 'product_management_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import 'order_detail_screen.dart';
import 'debtors_screen.dart';

// =============================================================================
// PALETA DE COLORES - TEMA CLARO MODERNO (AZUL) - Consistente con HomeScreen
// =============================================================================
class AppColors {
  // Fondos
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  
  // Color primario (azul vibrante)
  static const Color primary = Color(0xFF0062FF);
  static const Color primaryLight = Color(0xFFE6F0FF);
  static const Color primaryDark = Color(0xFF0052D6);
  
  // Textos
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  
  // Bordes y divisores
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  
  // Estados
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Sombras
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _showNotifications = false;
  bool _isLoading = true;
  String _bodegaName = "Cargando...";
  
  // Estadísticas dinámicas
  double _earningsToday = 0.0;
  int _ordersToday = 0;
  int _pendingOrdersCount = 0;
  
  // Custom Refresh Logic
  double _pullDistance = 0.0;
  bool _isRefreshing = false;

  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _weeklySales = [];
  String? _bestSellingProduct;
  String? _leastSellingProduct;
  double _totalCredit = 0.0;
  
  // Bottom Navigation con animación líquida
  int _currentNavIndex = 0;
  late final ValueNotifier<double> _pillPositionNotifier;
  
  // Subscription para eventos de push
  StreamSubscription<Map<String, dynamic>>? _orderEventSubscription;

  // Keys para refrescar las pantallas embebidas
  final GlobalKey<_EmbeddedProductsViewState> _productsKey = GlobalKey();
  final GlobalKey<_EmbeddedOrdersViewState> _ordersKey = GlobalKey();
  final GlobalKey<_EmbeddedProfileViewState> _profileKey = GlobalKey();

  // Nav items
  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.dashboard_rounded, 'iconOutlined': Icons.dashboard_outlined, 'label': 'Inicio'},
    {'icon': Icons.inventory_2_rounded, 'iconOutlined': Icons.inventory_2_outlined, 'label': 'Productos'},
    {'icon': Icons.receipt_long_rounded, 'iconOutlined': Icons.receipt_long_outlined, 'label': 'Pedidos'},
    {'icon': Icons.person_rounded, 'iconOutlined': Icons.person_outlined, 'label': 'Perfil'},
  ];

  @override
  void initState() {
    super.initState();
    
    // Configurar status bar para tema claro
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    _pillPositionNotifier = ValueNotifier<double>(0.0);
    
    _loadDashboardData();
    
    // Escuchar eventos de nuevos pedidos en tiempo real
    _orderEventSubscription = PushNotificationService().onOrderEvent.listen((event) {
      final eventType = event['type'];
      
      if (eventType == 'NEW_ORDER') {
        if (mounted) {
          _loadDashboardData();
          _ordersKey.currentState?.refresh();
        }
      }
      
      if (eventType == 'NAVIGATE_TO_ORDER') {
        final reservationId = event['reservation_id'];
        if (reservationId != null && mounted) {
          _navigateToOrderDetail(reservationId);
        }
      }
    });
    
    _checkPendingNavigation();
  }

  Future<void> _checkPendingNavigation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final pendingOrderId = PushNotificationService().pendingOrderId;
    if (pendingOrderId != null && mounted) {
      PushNotificationService().clearPendingNavigation();
      _navigateToOrderDetail(pendingOrderId);
    }
  }
  
  Future<void> _navigateToOrderDetail(String orderId) async {
    try {
      final orderData = await _api.getOrderById(orderId);
      if (orderData.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: orderData),
          ),
        ).then((_) {
          _loadDashboardData();
          _ordersKey.currentState?.refresh();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _orderEventSubscription?.cancel();
    _pillPositionNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = await SessionService().getUserId();
      if (userId != null) {
        final results = await Future.wait([
          _api.getMyInventory(userId),
          _api.getDashboardStats(userId),
        ]);
        
        final inventoryData = results[0];
        final statsData = results[1] as Map<String, dynamic>;
        
        if (mounted) {
          setState(() {
            if (inventoryData is Map && inventoryData['bodega_name'] != null) {
              _bodegaName = inventoryData['bodega_name'];
            }
            
            _earningsToday = (statsData['earnings_today'] ?? 0.0).toDouble();
            _ordersToday = statsData['orders_today'] ?? 0;
            _pendingOrdersCount = statsData['pending_orders_count'] ?? 0;
            _pendingOrders = List<Map<String, dynamic>>.from(
              statsData['pending_orders'] ?? []
            );
            _weeklySales = List<Map<String, dynamic>>.from(
              statsData['weekly_sales'] ?? []
            );
            _bestSellingProduct = statsData['best_selling_product'];
            _leastSellingProduct = statsData['least_selling_product'];
            _totalCredit = (statsData['total_credit'] ?? 0.0).toDouble();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onNavItemTapped(int index) {
    if (index == _currentNavIndex) return;
    
    // Animar la píldora hacia el nuevo índice
    _animatePillTo(index);
    
    setState(() {
      _currentNavIndex = index;
    });
    
    // Refrescar la pantalla correspondiente si es necesario
    if (index == 0) {
      _loadDashboardData();
    }
  }

  void _animatePillTo(int index) {
    const duration = Duration(milliseconds: 300);
    final startValue = _pillPositionNotifier.value;
    final endValue = index.toDouble();
    
    // Crear animación manual
    int steps = 30;
    double stepDuration = duration.inMilliseconds / steps;
    
    for (int i = 0; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: (stepDuration * i).toInt()), () {
        if (mounted) {
          double t = i / steps;
          // Curva easeOutCubic
          t = 1 - (1 - t) * (1 - t) * (1 - t);
          _pillPositionNotifier.value = startValue + (endValue - startValue) * t;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content - IndexedStack para mantener estado de las pantallas
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentNavIndex,
              children: [
                // 0 - Dashboard
                _buildDashboardContent(),
                // 1 - Productos
                _EmbeddedProductsView(
                  key: _productsKey,
                  onDataChanged: _loadDashboardData,
                ),
                // 2 - Pedidos
                _EmbeddedOrdersView(
                  key: _ordersKey,
                  onDataChanged: _loadDashboardData,
                ),
                // 3 - Perfil
                _EmbeddedProfileView(
                  key: _profileKey,
                  onDataChanged: _loadDashboardData,
                ),
              ],
            ),
          ),
          
          // Floating Glass Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildFloatingNavBar(),
          ),
          
          // Notifications Overlay
          if (_showNotifications)
            _buildNotificationsOverlay(),
        ],
      ),
    );
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _pullDistance = 60.0; // Mantener indicador visible
    });
    
    // Haptic feedback ligero
    HapticFeedback.lightImpact();
    
    await _loadDashboardData();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _pullDistance = 0.0;
      });
    }
  }

  void _resetPull() {
    setState(() {
      _pullDistance = 0.0;
    });
  }

  Widget _buildDashboardContent() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is OverscrollNotification) {
                    if (notification.overscroll < 0 && !_isRefreshing) {
                      // Dragging down at the top
                      setState(() {
                        // Apply resistance (damping)
                        _pullDistance -= notification.overscroll * 0.4;
                        if (_pullDistance > 120) _pullDistance = 120; // Max drag
                      });
                    }
                  } else if (notification is ScrollEndNotification) {
                    if (_pullDistance > 60 && !_isRefreshing) {
                      _startRefresh();
                    } else {
                      _resetPull();
                    }
                  } else if (notification is ScrollUpdateNotification) {
                    // Si el usuario hace scroll hacia abajo (contenido sube), resetear pull
                    if (notification.scrollDelta != null && notification.scrollDelta! > 0 && _pullDistance > 0) {
                      setState(() => _pullDistance = 0.0);
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  // ClampingScrollPhysics evita que el contenido se mueva al overscrollear
                  physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildAnalyticsRow(),
                      const SizedBox(height: 24),
                      _buildSalesChart(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ),
              
              // Custom Loading Indicator (Static Position Layer)
              if (_pullDistance > 0 || _isRefreshing)
                Positioned(
                  top: 20,
                  left: 0, 
                  right: 0,
                  child: Opacity(
                    opacity: _isRefreshing ? 1.0 : (_pullDistance / 60).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, _isRefreshing ? 0 : (_pullDistance > 60 ? 10 : -10 + (_pullDistance/3))), // Animación de entrada
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowMedium,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isRefreshing
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              )
                            : Transform.rotate(
                                angle: (_pullDistance / 10), // Rotar mientras se jala
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: _pullDistance > 60 ? AppColors.primary : AppColors.textMuted,
                                  size: 24,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double itemWidth = totalWidth / _navItems.length;
              
              return Stack(
                children: [
                  // Indicador deslizante "Liquid" animado
                  ValueListenableBuilder<double>(
                    valueListenable: _pillPositionNotifier,
                    builder: (context, position, child) {
                      final leftOffset = position * itemWidth + 8;
                      
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 50),
                        left: leftOffset,
                        top: 8,
                        bottom: 8,
                        width: itemWidth - 16,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
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
                  
                  // Items de navegación
                  Row(
                    children: _navItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final hasBadge = index == 2 && _pendingOrdersCount > 0;
                      
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onNavItemTapped(index),
                          behavior: HitTestBehavior.opaque,
                          child: ValueListenableBuilder<double>(
                            valueListenable: _pillPositionNotifier,
                            builder: (context, position, child) {
                              final isActive = position.round() == index;
                              final color = isActive ? Colors.white : AppColors.textMuted;

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        isActive ? item['icon'] : item['iconOutlined'],
                                        size: 26,
                                        color: color,
                                      ),
                                      if (hasBadge)
                                        Positioned(
                                          right: -8,
                                          top: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isActive ? Colors.white : AppColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Text(
                                              _pendingOrdersCount > 9 ? '9+' : '$_pendingOrdersCount',
                                              style: TextStyle(
                                                color: isActive ? AppColors.primary : Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['label'],
                                    style: TextStyle(
                                      fontSize: 11,
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _bodegaName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _showNotifications = !_showNotifications;
              });
            },
            child: Stack(
              children: [
                _buildCircleBtn(Icons.notifications_outlined, () {
                  setState(() => _showNotifications = !_showNotifications);
                }),
                if (_pendingOrdersCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$_pendingOrdersCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = "Buenos días";
    } else if (hour < 18) {
      greeting = "Buenas tardes";
    } else {
      greeting = "Buenas noches";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$greeting 👋",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Panel de Control",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                "Ganancias Hoy",
                _isLoading ? "..." : "S/ ${_earningsToday.toStringAsFixed(2)}",
                Icons.attach_money,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnalyticsCard(
                "Pedidos Hoy",
                _isLoading ? "..." : "$_ordersToday",
                Icons.shopping_bag_outlined,
                AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebtorsScreen()),
            ).then((_) => _loadDashboardData());
          },
          child: _buildCreditCard(),
        ),
      ],
    );
  }

  Widget _buildCreditCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withOpacity(0.15),
            AppColors.warning.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Dinero Fiado", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _isLoading ? "..." : "S/ ${_totalCredit.toStringAsFixed(2)}",
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: AppColors.warning, size: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    final List<FlSpot> spots = [];
    double maxValue = 50.0;
    
    for (int i = 0; i < _weeklySales.length && i < 7; i++) {
      final total = (_weeklySales[i]['total'] ?? 0.0).toDouble();
      spots.add(FlSpot(i.toDouble(), total));
      if (total > maxValue) maxValue = total;
    }
    
    if (spots.isEmpty) {
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }
    
    final maxY = (maxValue * 1.2).ceilToDouble();
    final interval = maxY > 0 ? (maxY / 4).ceilToDouble() : 10.0;
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Ventas de la Semana", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: Text("Esta semana", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < days.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[idx], style: TextStyle(color: AppColors.textMuted, fontSize: 12)));
                    return const Text('');
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 50, getTitlesWidget: (value, meta) => Text('S/${value.toInt()}', style: TextStyle(color: AppColors.textMuted, fontSize: 10)))),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 6, minY: 0, maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    barWidth: 3, isStrokeCapRound: true,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: AppColors.surface, strokeWidth: 2, strokeColor: AppColors.primary)),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.0)])),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_bestSellingProduct != null) Expanded(child: _buildProductTag("Más vendido", _bestSellingProduct!, AppColors.success)),
              if (_bestSellingProduct != null && _leastSellingProduct != null) const SizedBox(width: 12),
              if (_leastSellingProduct != null) Expanded(child: _buildProductTag("Menos vendido", _leastSellingProduct!, AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductTag(String label, String product, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(product, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Acciones Rápidas", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionCard("Gestionar Productos", "Ver inventario", Icons.inventory_2_outlined, AppColors.primary, () => _onNavItemTapped(1))),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard("Ver Pedidos", "$_pendingOrdersCount activos", Icons.receipt_long_outlined, AppColors.warning, () => _onNavItemTapped(2))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showNotifications = false),
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                top: 70, right: 20, width: 320,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 16, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Notificaciones", style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                              if (_pendingOrdersCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                                  child: Text("$_pendingOrdersCount nuevas", style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        if (_pendingOrders.isEmpty)
                          const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("No tienes notificaciones pendientes", style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center)))
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.separated(
                              shrinkWrap: true, padding: EdgeInsets.zero,
                              itemCount: _pendingOrders.length,
                              separatorBuilder: (c, i) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = _pendingOrders[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.shopping_bag, color: AppColors.primary, size: 20)),
                                  title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Nuevo Pedido", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(order['time_ago'] ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 10))]),
                                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(order['items_summary'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                    Text("Total: S/ ${(order['total_amount'] ?? 0.0).toDouble().toStringAsFixed(2)}", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ]),
                                  onTap: () {
                                    setState(() => _showNotifications = false);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))).then((_) => _loadDashboardData());
                                  },
                                );
                              },
                            ),
                          ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: GestureDetector(
                            onTap: () { setState(() => _showNotifications = false); _onNavItemTapped(2); },
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Ver todos los pedidos", style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 14)]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMBEDDED PRODUCTS VIEW - Vista de productos embebida
// =============================================================================
class _EmbeddedProductsView extends StatefulWidget {
  final VoidCallback? onDataChanged;
  
  const _EmbeddedProductsView({Key? key, this.onDataChanged}) : super(key: key);

  @override
  State<_EmbeddedProductsView> createState() => _EmbeddedProductsViewState();
}

class _EmbeddedProductsViewState extends State<_EmbeddedProductsView> {
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return const BodegueroScreen(isEmbedded: true);
  }
}

// =============================================================================
// EMBEDDED ORDERS VIEW - Vista de pedidos embebida
// =============================================================================
class _EmbeddedOrdersView extends StatefulWidget {
  final VoidCallback? onDataChanged;
  
  const _EmbeddedOrdersView({Key? key, this.onDataChanged}) : super(key: key);

  @override
  State<_EmbeddedOrdersView> createState() => _EmbeddedOrdersViewState();
}

class _EmbeddedOrdersViewState extends State<_EmbeddedOrdersView> {
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return const OrdersScreen(isEmbedded: true);
  }
}

// =============================================================================
// EMBEDDED PROFILE VIEW - Vista de perfil embebida
// =============================================================================
class _EmbeddedProfileView extends StatefulWidget {
  final VoidCallback? onDataChanged;
  
  const _EmbeddedProfileView({Key? key, this.onDataChanged}) : super(key: key);

  @override
  State<_EmbeddedProfileView> createState() => _EmbeddedProfileViewState();
}

class _EmbeddedProfileViewState extends State<_EmbeddedProfileView> {
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen(isEmbedded: true);
  }
}

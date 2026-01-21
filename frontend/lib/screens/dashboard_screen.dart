import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart'; // NUEVO: Para eventos en tiempo real
import 'login_screen.dart';
import 'product_management_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _showProfileMenu = false;
  bool _showNotifications = false;
  bool _isLoading = true;
  String _bodegaName = "Cargando...";
  
  // Estadísticas dinámicas
  double _earningsToday = 0.0;
  int _ordersToday = 0;
  int _pendingOrdersCount = 0;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _monthlySales = [];
  String? _bestSellingProduct;
  String? _leastSellingProduct;
  int _currentYear = DateTime.now().year;
  
  // NUEVO: Subscription para eventos de push
  StreamSubscription<Map<String, dynamic>>? _orderEventSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    
    // NUEVO: Escuchar eventos de nuevos pedidos en tiempo real
    _orderEventSubscription = PushNotificationService().onOrderEvent.listen((event) {
      final eventType = event['type'];
      
      // Actualizar dashboard cuando llega un nuevo pedido (solo refresh, no navegar)
      if (eventType == 'NEW_ORDER') {
        print('📦 [Dashboard] Nuevo pedido detectado, actualizando...');
        if (mounted) {
          _loadDashboardData();
        }
      }
      
      // Navegar al detalle cuando el usuario toca la notificación
      if (eventType == 'NAVIGATE_TO_ORDER') {
        final reservationId = event['reservation_id'];
        if (reservationId != null && mounted) {
          print('🧭 [Dashboard] Obteniendo datos del pedido: $reservationId');
          _navigateToOrderDetail(reservationId);
        }
      }
    });
    
    // NUEVO: Verificar si hay una navegación pendiente (app se abrió desde notificación)
    _checkPendingNavigation();
  }
  
  /// Verificar y procesar navegación pendiente desde notificaciones
  Future<void> _checkPendingNavigation() async {
    // Esperar un frame para asegurar que el widget está completamente montado
    await Future.delayed(const Duration(milliseconds: 100));
    
    final pendingOrderId = PushNotificationService().pendingOrderId;
    if (pendingOrderId != null && mounted) {
      print('🔔 [Dashboard] Procesando navegación pendiente: $pendingOrderId');
      PushNotificationService().clearPendingNavigation();
      _navigateToOrderDetail(pendingOrderId);
    }
  }
  
  /// Navegar al detalle del pedido obteniendo primero los datos completos
  Future<void> _navigateToOrderDetail(String orderId) async {
    try {
      final orderData = await _api.getOrderById(orderId);
      if (orderData.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: orderData),
          ),
        );
      } else {
        print('⚠️ No se encontró el pedido, navegando a OrdersScreen');
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrdersScreen()),
          );
        }
      }
    } catch (e) {
      print('❌ Error obteniendo pedido: $e');
      // Fallback a OrdersScreen si hay error
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _orderEventSubscription?.cancel(); // Limpiar subscription
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = await SessionService().getUserId();
      if (userId != null) {
        // Cargar nombre de bodega y estadísticas en paralelo
        final results = await Future.wait([
          _api.getMyInventory(userId),
          _api.getDashboardStats(userId),
        ]);
        
        final inventoryData = results[0];
        final statsData = results[1] as Map<String, dynamic>;
        
        if (mounted) {
          setState(() {
            // Nombre de bodega
            if (inventoryData is Map && inventoryData['bodega_name'] != null) {
              _bodegaName = inventoryData['bodega_name'];
            }
            
            // Estadísticas del día
            _earningsToday = (statsData['earnings_today'] ?? 0.0).toDouble();
            _ordersToday = statsData['orders_today'] ?? 0;
            _pendingOrdersCount = statsData['pending_orders_count'] ?? 0;
            _pendingOrders = List<Map<String, dynamic>>.from(
              statsData['pending_orders'] ?? []
            );
            _monthlySales = List<Map<String, dynamic>>.from(
              statsData['monthly_sales'] ?? []
            );
            _bestSellingProduct = statsData['best_selling_product'];
            _leastSellingProduct = statsData['least_selling_product'];
            _currentYear = statsData['current_year'] ?? DateTime.now().year;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Panel de Control",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Resumen del día",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Analytics Cards
                        _buildAnalyticsRow(),
                        const SizedBox(height: 24),
                        
                        // Sales Chart
                        _buildSalesChart(),
                        const SizedBox(height: 24),
                        
                        // Products Section
                        _buildProductsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Profile Menu Overlay
          if (_showProfileMenu)
            _buildProfileMenuOverlay(),
          
          // Notifications Overlay
          if (_showNotifications)
            _buildNotificationsOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: () {
              setState(() {
                _showProfileMenu = !_showProfileMenu;
                _showNotifications = false;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00D9FF),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF1A1F2E),
                child: Icon(Icons.store, color: Color(0xFF00D9FF), size: 24),
              ),
            ),
          ),
          
          Text(
            _bodegaName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          
          // Notification Bell
          GestureDetector(
            onTap: () {
              setState(() {
                _showNotifications = !_showNotifications;
                _showProfileMenu = false;
              });
            },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
                    if (_pendingOrdersCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
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

  Widget _buildAnalyticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCard(
            "Ganancias Hoy",
            _isLoading ? "..." : "S/ ${_earningsToday.toStringAsFixed(2)}",
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            "Pedidos Hoy",
            _isLoading ? "..." : "$_ordersToday",
            Icons.shopping_bag,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "+12%",
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    // Generar spots dinámicos desde _monthlySales
    final List<FlSpot> spots = [];
    double maxValue = 100.0; // Mínimo para el eje Y
    
    for (int i = 0; i < _monthlySales.length && i < 12; i++) {
      final total = (_monthlySales[i]['total'] ?? 0.0).toDouble();
      spots.add(FlSpot(i.toDouble(), total));
      if (total > maxValue) maxValue = total;
    }
    
    // Si no hay datos, usar spots vacíos
    if (spots.isEmpty) {
      for (int i = 0; i < 12; i++) {
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }
    
    // Redondear maxY al siguiente múltiplo de 100
    final maxY = ((maxValue / 100).ceil() * 100).toDouble();
    final interval = maxY > 0 ? (maxY / 4) : 100.0;
    
    const months = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ventas Mensuales",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$_currentYear",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[idx],
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'S/${value.toInt()}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D9FF),
                        const Color(0xFF00D9FF).withOpacity(0.5),
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D9FF).withOpacity(0.3),
                          const Color(0xFF00D9FF).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProductTag(
                "Más vendido", 
                _bestSellingProduct ?? "Sin datos", 
                Colors.green
              ),
              _buildProductTag(
                "Menos vendido", 
                _leastSellingProduct ?? "Sin datos", 
                Colors.orange
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductTag(String label, String product, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            product,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BodegueroScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00D9FF).withOpacity(0.2),
              const Color(0xFF1A1F2E).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Gestionar Productos",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Ver inventario completo",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.black,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenuOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showProfileMenu = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 70, left: 20),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(Icons.person, "Mi perfil", true, onTap: () async {
                        setState(() => _showProfileMenu = false);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                        // Reload bodega name if changed
                        if (result == true) {
                          _loadDashboardData();
                        }
                      }),
                      _buildMenuItem(Icons.receipt_long, "Pedidos recientes", true, onTap: () async {
                        setState(() => _showProfileMenu = false);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                        // Refrescar al volver, por si cambió el estado de algún pedido
                        _loadDashboardData();
                      }),
                      _buildMenuItem(Icons.edit, "Editar productos", false),
                      _buildMenuItem(Icons.local_offer, "Crear ofertas", false),
                      const Divider(color: Colors.white10, height: 1),
                      _buildMenuItem(Icons.logout, "Cerrar sesión", true, onTap: () async {
                        await SessionService().logout();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String text, bool isActive, {VoidCallback? onTap}) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.redAccent : Colors.white.withOpacity(0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isActive ? Colors.redAccent : Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showNotifications = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 70, right: 20),
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Pedidos Activos",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_pendingOrdersCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Mostrar pedidos reales o mensaje vacío
                      if (_pendingOrders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              "No hay pedidos activos",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        // FIX: Usar Flexible + ListView para evitar overflow en pantallas pequeñas
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _pendingOrders.length,
                            itemBuilder: (context, index) => _buildNotificationItem(_pendingOrders[index]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> order) {
    final name = order['client_name'] ?? "Cliente";
    final products = order['items_summary'] ?? "";
    final total = "S/ ${(order['total_amount'] ?? 0.0).toStringAsFixed(2)}";
    final time = order['time_ago'] ?? "";
    
    return InkWell(
      onTap: () async {
        setState(() => _showNotifications = false);
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
        // Recargar datos si se actualizó el pedido
        if (result == true) {
          _loadDashboardData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              products,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'product_management_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _showProfileMenu = false;
  bool _showNotifications = false;
  final int _pendingOrders = 3; // Static for now
  String _bodegaName = "Cargando...";

  @override
  void initState() {
    super.initState();
    _loadBodegaName();
  }

  Future<void> _loadBodegaName() async {
    try {
      final userId = await SessionService().getUserId();
      if (userId != null) {
        final data = await _api.getMyInventory(userId);
        if (mounted && data is Map && data['bodega_name'] != null) {
          setState(() {
            _bodegaName = data['bodega_name'];
          });
        }
      }
    } catch (e) {
      print('Error loading bodega name: $e');
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
                if (_pendingOrders > 0)
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
                        '$_pendingOrders',
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
            "S/ 156.50",
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            "Pedidos",
            "12",
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
                child: const Text(
                  "2024",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
                  horizontalInterval: 100,
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
                        const months = ['E', 'F', 'M', 'A', 'M', 'J'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt()],
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
                      interval: 100,
                      reservedSize: 40,
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
                maxX: 5,
                minY: 0,
                maxY: 400,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 150),
                      FlSpot(1, 200),
                      FlSpot(2, 180),
                      FlSpot(3, 280),
                      FlSpot(4, 320),
                      FlSpot(5, 290),
                    ],
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
              _buildProductTag("Más vendido", "Inca Kola 1.5L", Colors.green),
              _buildProductTag("Menos vendido", "Detergente Ace", Colors.orange),
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
                          _loadBodegaName();
                        }
                      }),
                      _buildMenuItem(Icons.receipt_long, "Pedidos recientes", true, onTap: () {
                        setState(() => _showProfileMenu = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
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
                                '$_pendingOrders',
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
                      _buildNotificationItem(
                        "Juan P.",
                        "2x Arroz Paisana, 1x Aceite Primor",
                        "S/ 12.50",
                        "Hace 5 min",
                      ),
                      _buildNotificationItem(
                        "María G.",
                        "1x Inca Kola 2L, 3x Galletas Soda",
                        "S/ 18.00",
                        "Hace 15 min",
                      ),
                      _buildNotificationItem(
                        "Carlos R.",
                        "1x Detergente Ace, 2x Papel Higiénico",
                        "S/ 24.50",
                        "Hace 1 hora",
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

  Widget _buildNotificationItem(String name, String products, String total, String time) {
    return Container(
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
    );
  }
}

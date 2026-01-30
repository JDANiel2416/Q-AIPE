import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'shared_drawer.dart';
import 'home_colors.dart';
import 'ticket_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen>
    with TickerProviderStateMixin, UserDrawerMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initDrawer(); // Inicializar drawer
    // Nota: El OverlayStyle se maneja en el build
    _loadOrders();
  }

  @override
  void dispose() {
    disposeDrawer();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final userId = await SessionService().getUserId();
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final orders = await _apiService.getUserOrders(userId);

    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Pagado';
      case 'COMPLETED':
        return 'Completado';
      case 'CREDIT':
        return 'Fiado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return HomeColors.success;
      case 'COMPLETED':
        return Colors.blue;
      case 'CREDIT':
        return HomeColors.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.80;
    final isDark = HomeColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: HomeColors.background(context),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeColors.background(context),
        body: GestureDetector(
          onHorizontalDragStart: (details) =>
              onHorizontalDragStart(details, drawerWidth),
          onHorizontalDragUpdate: (details) =>
              onHorizontalDragUpdate(details, drawerWidth),
          onHorizontalDragEnd: onHorizontalDragEnd,
          child: Stack(
            children: [
              // Contenido principal
              SafeArea(
                child: Column(
                  children: [
                    // AppBar personalizado con botón de menú
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          buildCircleBtn(Icons.menu_rounded, openDrawer),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Historial de Pedidos",
                              style: TextStyle(
                                color: HomeColors.textPrimary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Contenido
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: HomeColors.primary(context),
                              ),
                            )
                          : _orders.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) =>
                                  _buildOrderItem(_orders[index]),
                            ),
                    ),
                  ],
                ),
              ),

              // Drawer overlay
              buildDrawerOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: HomeColors.textMuted(context),
          ),
          const SizedBox(height: 16),
          Text(
            "No tienes pedidos completados",
            style: TextStyle(
              color: HomeColors.textSecondary(context),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tus pedidos pagados aparecerán aquí",
            style: TextStyle(
              color: HomeColors.textMuted(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final status = order['status'] ?? 'PAID';
    final statusColor = _getStatusColor(status);
    final isClickable = status == 'PENDING' || status == 'CREDIT';

    return GestureDetector(
      onTap: isClickable
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketScreen(
                    ticketData: {
                      'items': items,
                      'total': order['total_amount'],
                      'qr_data': order['qr_data'] ?? '',
                      'formatted_name': "Mi Pedido",
                    },
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: HomeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClickable
                ? HomeColors.primary(context)
                : HomeColors.border(context),
            width: isClickable ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: HomeColors.shadowLight(context),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.store, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['bodega_name'] ?? 'Bodega',
                          style: TextStyle(
                            color: HomeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(order['created_at'] ?? ''),
                          style: TextStyle(
                            color: HomeColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isClickable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text(
                                "Ver Ticket",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: HomeColors.primary(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: HomeColors.primary(context),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Items... (Rest of the code)

            // Items
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: HomeColors.primary(
                                        context,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "x${item['quantity']}",
                                      style: TextStyle(
                                        color: HomeColors.primary(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    item['product_name'] ?? '',
                                    style: TextStyle(
                                      color: HomeColors.textPrimary(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "S/ ${(item['total_price'] ?? 0.0).toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: HomeColors.textSecondary(context),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),

                  Divider(color: HomeColors.divider(context), height: 24),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total",
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "S/ ${(order['total_amount'] ?? 0.0).toStringAsFixed(2)}",
                        style: TextStyle(
                          color: HomeColors.primary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

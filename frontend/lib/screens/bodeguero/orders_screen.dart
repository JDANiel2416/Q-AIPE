import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../services/push_notification_service.dart';
import 'order_detail_screen.dart';

import 'bodeguero_colors.dart';

class OrdersScreen extends StatefulWidget {
  final bool isEmbedded;

  const OrdersScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;

  // PageView y barra líquida
  late final PageController _pageController;
  late final ValueNotifier<double> _pillPositionNotifier;
  int _currentTabIndex = 0;
  bool _isDraggingBar = false;

  // Categorías de pedidos
  final List<Map<String, dynamic>> _tabs = [
    {
      'name': 'Pendientes',
      'icon': Icons.pending_actions_outlined,
      'filter': 'PENDING',
    },
    {'name': 'Historial', 'icon': Icons.history_outlined, 'filter': 'HISTORY'},
  ];

  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _pageController = PageController();
    _pillPositionNotifier = ValueNotifier<double>(0.0);
    _pageController.addListener(_handlePageScroll);
    _loadOrders();

    // Escuchar notificaciones en tiempo real para actualizar la lista
    _orderSubscription = PushNotificationService().onOrderEvent.listen((event) {
      if (event['type'] == 'NEW_ORDER') {
        print(
          "🔔 [OrdersScreen] Nuevo pedido detectado, actualizando lista...",
        );
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
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
      setState(() {
        _currentTabIndex = newIndex;
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final userId = await SessionService().getUserId();
    if (userId != null) {
      final orders = await _api.getOrders(userId);
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _getFilteredOrders(String filter) {
    if (filter == "PENDING") {
      return _orders.where((o) => o['status'] == 'PENDING').toList();
    } else {
      return _orders.where((o) => o['status'] != 'PENDING').toList();
    }
  }

  int _getOrderCount(String filter) {
    return _getFilteredOrders(filter).length;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return BColors.warning;
      case 'PAID':
        return BColors.success;
      case 'CREDIT':
        return BColors.primary(context);
      case 'CANCELLED':
        return BColors.error;
      default:
        return BColors.textMuted(context);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'PAID':
        return 'Pagado';
      case 'CREDIT':
        return 'Fiado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (!_isLoading) _buildGlassCategoryBar(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: BColors.primary(context),
                      ),
                    )
                  : PageView(
                      controller: _pageController,
                      children: _tabs.map((tab) {
                        return _buildOrdersView(tab['filter']);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
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
                  color: BColors.primaryLight(context).withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: BColors.primary(context),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pedidos",
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  "${_orders.length} pedidos totales",
                  style: TextStyle(
                    color: BColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: BColors.surface(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: BColors.shadowLight(context),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: BColors.primary(context)),
              onPressed: _loadOrders,
            ),
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
        color: BColors.surface(context).withOpacity(0.6),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowMedium(context),
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
                final double itemWidth = totalWidth / _tabs.length;

                return GestureDetector(
                  onHorizontalDragStart: (_) {
                    setState(() {
                      _isDraggingBar = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    if (delta != 0 && _pageController.hasClients) {
                      final double deltaIndex = delta / itemWidth;
                      double targetPage =
                          _pillPositionNotifier.value + deltaIndex;
                      targetPage = targetPage.clamp(0.0, _tabs.length - 1.0);

                      _pillPositionNotifier.value = targetPage;

                      final double viewportWidth =
                          _pageController.position.viewportDimension;
                      final double targetPixels = targetPage * viewportWidth;

                      _pageController.jumpTo(targetPixels);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _isDraggingBar = false;
                    });
                    final int finalIndex = _pillPositionNotifier.value.round();
                    _pageController.animateToPage(
                      finalIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Stack(
                    children: [
                      // Indicador deslizante "Liquid"
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
                                gradient: LinearGradient(
                                  colors: [
                                    BColors.primary(context),
                                    BColors.primaryDark(context),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: BColors.primary(
                                      context,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Items de tabs
                      Row(
                        children: _tabs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tab = entry.value;
                          final count = _getOrderCount(tab['filter']);

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
                                  final color = isActive
                                      ? Colors.white
                                      : BColors.textSecondary(context);

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            tab['icon'],
                                            size: 20,
                                            color: color,
                                          ),
                                          if (count > 0 &&
                                              tab['filter'] == 'PENDING') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.white.withOpacity(
                                                        0.2,
                                                      )
                                                    : BColors.warning,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isActive
                                                      ? Colors.white
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tab['name'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.w500,
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

  Widget _buildOrdersView(String filter) {
    final orders = _getFilteredOrders(filter);

    if (orders.isEmpty) {
      return _buildEmptyState(filter);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: BColors.primary(context),
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: widget.isEmbedded ? 120 : 10,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final date = DateTime.parse(order['created_at']);
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    final statusColor = _getStatusColor(order['status']);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
        if (result == true) {
          _loadOrders();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: BColors.shadowMedium(context),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: BColors.border(context), width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BColors.primaryLight(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: BColors.primary(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['client_name'],
                        style: TextStyle(
                          color: BColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: BColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: BColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order['delivery_type'] == 'DELIVERY') ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      size: 14,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    _getStatusText(order['status']),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: BColors.divider(context)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${(order['items'] as List).length} items",
                  style: TextStyle(
                    color: BColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "S/ ${order['total_amount'].toStringAsFixed(2)}",
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BColors.primaryLight(context),
            ),
            child: Icon(
              filter == 'PENDING'
                  ? Icons.pending_actions_outlined
                  : Icons.history_outlined,
              size: 50,
              color: BColors.primary(context),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            filter == 'PENDING'
                ? "No hay pedidos pendientes"
                : "No hay pedidos en el historial",
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter == 'PENDING'
                ? "¡Los pedidos nuevos aparecerán aquí!"
                : "Los pedidos completados se mostrarán aquí",
            style: TextStyle(
              color: BColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

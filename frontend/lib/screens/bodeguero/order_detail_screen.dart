import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

import 'bodeguero_colors.dart';

class OrderDetailScreen extends StatefulWidget {
  final dynamic order;
  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _fullOrder = {};
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkOrderData();
  }

  void _checkOrderData() {
    bool isDelivery = widget.order['delivery_type'] == 'DELIVERY';
    bool hasAddress = widget.order['delivery_address'] != null;

    // Si tenemos items Y (no es delivery O (es delivery y tiene address))
    // Entonces podemos usar los datos que vinieron de la lista.
    // Si no, forzamos recarga para obtener coordendas y dirección.
    if (widget.order['items'] != null && (!isDelivery || hasAddress)) {
      _fullOrder = widget.order;
      _isLoading = false;
    } else {
      // Si solo vino ID o faltan datos de delivery, cargamos detalle completo
      _loadOrderDetails();
    }
  }

  Future<void> _loadOrderDetails() async {
    final orderId = widget.order['id'];
    if (orderId == null) return;

    try {
      final details = await _api.getOrderById(orderId);
      if (mounted) {
        setState(() {
          _fullOrder = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final result = await _api.updateOrderStatus(
      _fullOrder['id'] ?? widget.order['id'],
      status,
    );
    setState(() => _isUpdating = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: BColors.primary(context),
          ),
        );
        Navigator.pop(context, true); // Return true to refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: BColors.background(context),
        body: Center(
          child: CircularProgressIndicator(color: BColors.primary(context)),
        ),
      );
    }

    final order = _fullOrder;
    // Si falló la carga y está vacío, mostrar error
    if (order.isEmpty) {
      return Scaffold(
        backgroundColor: BColors.background(context),
        appBar: AppBar(title: Text("Error")),
        body: const Center(child: Text("No se pudo cargar el pedido")),
      );
    }

    final date = DateTime.parse(order['created_at']);
    final isPending = order['status'] == 'PENDING';

    return Scaffold(
      backgroundColor: BColors.background(context),
      body: Stack(
        children: [
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
                        // Header Info
                        _buildInfoCard(order, date),
                        const SizedBox(height: 24),

                        // Delivery Section (only if delivery)
                        if (order['delivery_type'] == 'DELIVERY') ...[
                          _buildDeliverySection(order),
                          const SizedBox(height: 24),
                        ],

                        // Items List
                        Text(
                          "Detalle del Pedido",
                          style: TextStyle(
                            color: BColors.textPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildItemsList(order['items']),
                        const SizedBox(height: 24),

                        // Total
                        _buildTotalRow(order),
                      ],
                    ),
                  ),
                ),

                // Action Buttons (Only for Pending)
                if (isPending) _buildActionButtons(),
              ],
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  color: BColors.primary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
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
          Text(
            "Detalle de Pedido",
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(dynamic order, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowLight(context),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: BColors.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person_outline, "Cliente", order['client_name']),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: BColors.divider(context)),
          ),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            "Fecha",
            DateFormat('dd/MM/yyyy').format(date),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: BColors.divider(context)),
          ),
          _buildInfoRow(
            Icons.access_time,
            "Hora",
            DateFormat('HH:mm').format(date),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BColors.primary(context), size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: BColors.textSecondary(context))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliverySection(dynamic order) {
    final address = order['delivery_address'] ?? 'Sin dirección';
    final lat = order['delivery_lat'];
    final lng = order['delivery_lng'];
    final fee = order['delivery_fee'] ?? 0.0;
    final hasCoords = lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delivery_dining, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "DELIVERY",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (fee > 0)
                Text(
                  "+ S/ ${fee.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                color: BColors.primary(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          // Map button
          if (hasCoords) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openMap(lat, lng),
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text("Ver en Mapa"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Coordenadas expiradas o no disponibles",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    // Try Google Maps first, then fallback to web
    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        // Intentar abrir web directamente si falla la app nativa o canLaunchUrl dice false
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No se pudo abrir el mapa: $e")));
      }
    }
  }

  Widget _buildItemsList(List<dynamic> items) {
    return Container(
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BColors.border(context), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowLight(context),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: BColors.primaryLight(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${item['quantity']}x",
                    style: TextStyle(
                      color: BColors.primary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'],
                        style: TextStyle(
                          color: BColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "S/ ${item['unit_price'].toStringAsFixed(2)} c/u",
                        style: TextStyle(
                          color: BColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "S/ ${item['total_price'].toStringAsFixed(2)}",
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow(dynamic order) {
    final double total = (order['total_amount'] ?? 0).toDouble();
    final double deliveryFee = (order['delivery_fee'] ?? 0).toDouble();
    final double subtotal = total - deliveryFee;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BColors.primary(context).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: BColors.primary(context).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (deliveryFee > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal",
                  style: TextStyle(
                    color: BColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                Text(
                  "S/ ${subtotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Delivery",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "S/ ${deliveryFee.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: BColors.divider(context)),
            ),
          ],

          Row(
            children: [
              Text(
                "TOTAL A COBRAR",
                style: TextStyle(
                  color: BColors.textSecondary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                "S/ ${total.toStringAsFixed(2)}",
                style: TextStyle(
                  color: BColors.primary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowMedium(context),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Fiado",
                  Icons.handshake_outlined,
                  BColors.warning,
                  () => _updateStatus('CREDIT'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  "Pagado",
                  Icons.check_circle_outline,
                  BColors.success,
                  () => _updateStatus('PAID'),
                  isPrimary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              "Cancelar Pedido",
              Icons.cancel_outlined,
              BColors.error,
              () => _updateStatus('CANCELLED'),
              isOutlined: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isOutlined = false,
    bool isPrimary = false,
  }) {
    // Si es primario (Pagado), usamos un diseño más fuerte
    // Si es outline (Cancelar), usamos borde
    // Si es estándar (Fiado), usamos fondo suave

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isOutlined
              ? Colors.transparent
              : (isPrimary ? color : color.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
          border: isOutlined
              ? Border.all(color: color.withOpacity(0.3))
              : (isPrimary ? null : Border.all(color: color.withOpacity(0.2))),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

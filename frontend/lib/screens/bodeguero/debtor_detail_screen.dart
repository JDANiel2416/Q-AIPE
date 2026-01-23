import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'bodeguero_colors.dart';

class DebtorDetailScreen extends StatefulWidget {
  final String debtorId;
  final String debtorName;

  const DebtorDetailScreen({
    Key? key,
    required this.debtorId,
    required this.debtorName,
  }) : super(key: key);

  @override
  State<DebtorDetailScreen> createState() => _DebtorDetailScreenState();
}

class _DebtorDetailScreenState extends State<DebtorDetailScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String _clientName = "";
  String _phone = "";
  double _totalDebt = 0.0;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _clientName = widget.debtorName;
    _loadDebtorOrders();
  }

  Future<void> _loadDebtorOrders() async {
    try {
      final userId = await SessionService().getUserId();
      if (userId != null) {
        final data = await _api.getDebtorOrders(userId, widget.debtorId);
        if (mounted) {
          setState(() {
            _clientName = data['client_name'] ?? widget.debtorName;
            _phone = data['phone'] ?? '';
            _totalDebt = (data['total_debt'] ?? 0.0).toDouble();
            _orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading debtor orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      appBar: AppBar(
        backgroundColor: BColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: BColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _clientName,
          style: TextStyle(
            color: BColors.textPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con total del cliente
                _buildClientHeader(),
                
                // Lista de pedidos
                Expanded(
                  child: _orders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_orders[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildClientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        border: Border(
          bottom: BorderSide(color: BColors.border(context)),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: BColors.primaryLight(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _clientName.isNotEmpty ? _clientName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: BColors.primary(context),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _clientName,
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _phone,
                    style: TextStyle(
                      color: BColors.textMuted(context),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  "${_orders.length} pedido${_orders.length != 1 ? 's' : ''} pendiente${_orders.length != 1 ? 's' : ''}",
                  style: TextStyle(
                    color: BColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Debe",
                style: TextStyle(
                  color: BColors.textMuted(context),
                  fontSize: 11,
                ),
              ),
              Text(
                "S/ ${_totalDebt.toStringAsFixed(2)}",
                style: TextStyle(
                  color: BColors.warning,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final date = order['date'] ?? '';
    final time = order['time'] ?? '';
    final totalAmount = (order['total_amount'] ?? 0.0).toDouble();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowMedium(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del pedido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BColors.warning.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: BColors.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: TextStyle(
                        color: BColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: BColors.textSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: BColors.textSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BColors.warning,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "S/ ${totalAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de productos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) => _buildProductItem(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    final name = item['product_name'] ?? '';
    final quantity = item['quantity'] ?? 1;
    final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
    final totalPrice = (item['total_price'] ?? 0.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Cantidad
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: BColors.primaryLight(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "$quantity",
                style: TextStyle(
                  color: BColors.primary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Nombre y precio unitario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "S/ ${unitPrice.toStringAsFixed(2)} c/u",
                  style: TextStyle(
                    color: BColors.textMuted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Total del item
          Text(
            "S/ ${totalPrice.toStringAsFixed(2)}",
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
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
            color: BColors.textMuted(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "Sin pedidos pendientes",
            style: TextStyle(
              color: BColors.textSecondary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

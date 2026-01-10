import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final dynamic order;
  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _api = ApiService();
  bool _isUpdating = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final result = await _api.updateOrderStatus(widget.order['id'], status);
    setState(() => _isUpdating = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFF00D9FF),
          ),
        );
        Navigator.pop(context, true); // Return true to refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final date = DateTime.parse(order['created_at']);
    final isPending = order['status'] == 'PENDING';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          const MinimalistBackground(),
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
                        
                        // Items List
                        const Text(
                          "Detalle del Pedido",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildItemsList(order['items']),
                        const SizedBox(height: 24),
                        
                        // Total
                        _buildTotalRow(order['total_amount']),
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
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            "Detalle de Pedido",
            style: TextStyle(
              color: Colors.white,
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person, "Cliente", order['client_name']),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.calendar_today, "Fecha", DateFormat('dd/MM/yyyy').format(date)),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.access_time, "Hora", DateFormat('HH:mm').format(date)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${item['quantity']}x",
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "S/ ${item['unit_price'].toStringAsFixed(2)} c/u",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "S/ ${item['total_price'].toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _buildTotalRow(dynamic amount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00D9FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text(
            "TOTAL",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Text(
            "S/ ${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Color(0xFF00D9FF),
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -4),
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
                  Icons.handshake,
                  Colors.blue,
                  () => _updateStatus('CREDIT'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  "Pago Confirmado",
                  Icons.check_circle,
                  Colors.green,
                  () => _updateStatus('PAID'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              "Cancelar Pedido",
              Icons.cancel,
              Colors.red,
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
    VoidCallback onTap,
    {bool isOutlined = false}
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.transparent : color,
        foregroundColor: isOutlined ? color : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isOutlined ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
        elevation: isOutlined ? 0 : 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class MinimalistBackground extends StatelessWidget {
  const MinimalistBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E1A),
            Color(0xFF0F1419),
            Color(0xFF0A0E1A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

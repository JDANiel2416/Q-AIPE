import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'debtor_detail_screen.dart';
import 'bodeguero_colors.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({Key? key}) : super(key: key);

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  double _totalCredit = 0.0;
  List<Map<String, dynamic>> _debtors = [];

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  Future<void> _loadDebtors() async {
    try {
      final userId = await SessionService().getUserId();
      if (userId != null) {
        final data = await _api.getDebtors(userId);
        if (mounted) {
          setState(() {
            _totalCredit = (data['total_credit'] ?? 0.0).toDouble();
            _debtors = List<Map<String, dynamic>>.from(data['debtors'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading debtors: $e');
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
          "Dinero Fiado",
          style: TextStyle(
            color: BColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con total
                _buildTotalHeader(),
                
                // Lista de deudores
                Expanded(
                  child: _debtors.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _debtors.length,
                          itemBuilder: (context, index) {
                            return _buildDebtorCard(_debtors[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BColors.warning.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: BColors.warning.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Text(
            "Total Pendiente",
            style: TextStyle(
              color: BColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "S/ ${_totalCredit.toStringAsFixed(2)}",
            style: TextStyle(
              color: BColors.warning,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${_debtors.length} cliente${_debtors.length != 1 ? 's' : ''} con deuda",
            style: TextStyle(
              color: BColors.textMuted(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtorCard(Map<String, dynamic> debtor) {
    final userId = debtor['user_id'] ?? '';
    final name = debtor['client_name'] ?? 'Cliente Anónimo';
    final totalDebt = (debtor['total_debt'] ?? 0.0).toDouble();
    final ordersCount = debtor['orders_count'] ?? 1;
    final phone = debtor['phone'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DebtorDetailScreen(
              debtorId: userId,
              debtorName: name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BColors.primaryLight(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: BColors.primary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Nombre y teléfono
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$ordersCount pedido${ordersCount != 1 ? 's' : ''} pendiente${ordersCount != 1 ? 's' : ''}",
                  style: TextStyle(
                    color: BColors.textMuted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Monto y flecha
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "S/ ${totalDebt.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: BColors.warning,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: TextStyle(
                        color: BColors.textMuted(context),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: BColors.textMuted(context),
                size: 24,
              ),
            ],
          ),
        ],
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
            Icons.check_circle_outline,
            size: 80,
            color: BColors.textMuted(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "¡Sin deudas pendientes!",
            style: TextStyle(
              color: BColors.textSecondary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No tienes clientes con dinero fiado",
            style: TextStyle(
              color: BColors.textMuted(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

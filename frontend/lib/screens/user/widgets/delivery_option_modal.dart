import 'package:flutter/material.dart';
import '../home_colors.dart';

/// Resultado del modal de opción de delivery
class DeliveryOptionResult {
  final String deliveryType; // "PICKUP" | "DELIVERY"
  final String? address;
  final double? lat;
  final double? lng;
  final double deliveryFee;

  DeliveryOptionResult({
    required this.deliveryType,
    this.address,
    this.lat,
    this.lng,
    this.deliveryFee = 0,
  });
}

/// Modal para seleccionar tipo de entrega
class DeliveryOptionModal extends StatefulWidget {
  final String bodegaName;
  final bool hasDelivery;
  final double deliveryFee;
  final double deliveryRadius;
  final double subtotal;
  final double userLat;
  final double userLng;

  const DeliveryOptionModal({
    Key? key,
    required this.bodegaName,
    required this.hasDelivery,
    required this.deliveryFee,
    required this.deliveryRadius,
    required this.subtotal,
    required this.userLat,
    required this.userLng,
  }) : super(key: key);

  @override
  State<DeliveryOptionModal> createState() => _DeliveryOptionModalState();
}

class _DeliveryOptionModalState extends State<DeliveryOptionModal> {
  String _selectedType = "PICKUP";
  final _addressController = TextEditingController();
  bool _isAddressValid = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _total {
    if (_selectedType == "DELIVERY") {
      return widget.subtotal + widget.deliveryFee;
    }
    return widget.subtotal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeColors.textMuted(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            "¿Cómo deseas recibir tu pedido?",
            style: TextStyle(
              color: HomeColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.bodegaName,
            style: TextStyle(
              color: HomeColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Options
          Row(
            children: [
              Expanded(
                child: _buildOption(
                  type: "PICKUP",
                  icon: Icons.store,
                  label: "Recoger",
                  subtitle: "En tienda",
                  enabled: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOption(
                  type: "DELIVERY",
                  icon: Icons.delivery_dining,
                  label: "Delivery",
                  subtitle: widget.hasDelivery
                      ? "+S/ ${widget.deliveryFee.toStringAsFixed(1)}"
                      : "No disponible",
                  enabled: widget.hasDelivery,
                ),
              ),
            ],
          ),

          // Address input (if delivery)
          if (_selectedType == "DELIVERY") ...[
            const SizedBox(height: 20),
            TextField(
              controller: _addressController,
              onChanged: (val) =>
                  setState(() => _isAddressValid = val.length > 5),
              style: TextStyle(color: HomeColors.textPrimary(context)),
              decoration: InputDecoration(
                hintText: "Escribe tu dirección",
                hintStyle: TextStyle(color: HomeColors.textMuted(context)),
                prefixIcon: Icon(
                  Icons.location_on,
                  color: HomeColors.primary(context),
                ),
                filled: true,
                fillColor: HomeColors.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HomeColors.primary(context)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeColors.primary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: HomeColors.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Usaremos tu ubicación GPS actual para la entrega",
                      style: TextStyle(
                        color: HomeColors.primary(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomeColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  "Subtotal",
                  "S/ ${widget.subtotal.toStringAsFixed(2)}",
                ),
                if (_selectedType == "DELIVERY") ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    "Delivery",
                    "+ S/ ${widget.deliveryFee.toStringAsFixed(2)}",
                  ),
                ],
                const Divider(height: 16),
                _buildSummaryRow(
                  "Total",
                  "S/ ${_total.toStringAsFixed(2)}",
                  isBold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canConfirm ? _onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.primary(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: HomeColors.surfaceVariant(context),
              ),
              child: Text(
                _selectedType == "PICKUP"
                    ? "Confirmar Recojo"
                    : "Confirmar Delivery",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool get _canConfirm {
    if (_selectedType == "PICKUP") return true;
    return _isAddressValid;
  }

  Widget _buildOption({
    required String type,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool enabled,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedType = type) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? HomeColors.primary(context).withOpacity(0.15)
              : HomeColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? HomeColors.primary(context)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: enabled
                  ? (isSelected
                        ? HomeColors.primary(context)
                        : HomeColors.textSecondary(context))
                  : HomeColors.textMuted(context),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? HomeColors.textPrimary(context)
                    : HomeColors.textMuted(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: enabled
                    ? (type == "DELIVERY"
                          ? HomeColors.primary(context)
                          : HomeColors.textSecondary(context))
                    : HomeColors.textMuted(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: HomeColors.textSecondary(context),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: HomeColors.textPrimary(context),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      DeliveryOptionResult(
        deliveryType: _selectedType,
        address: _selectedType == "DELIVERY" ? _addressController.text : null,
        lat: _selectedType == "DELIVERY" ? widget.userLat : null,
        lng: _selectedType == "DELIVERY" ? widget.userLng : null,
        deliveryFee: _selectedType == "DELIVERY" ? widget.deliveryFee : 0,
      ),
    );
  }
}

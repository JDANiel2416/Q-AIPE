import 'package:flutter/material.dart';
import '../../../../models/search_models.dart'; // BodegaSearchResult
import '../home_colors.dart';

class UnifiedOrderCard extends StatelessWidget {
  final List<BodegaSearchResult> results;
  final VoidCallback onConfirmAll;
  final Function(BodegaSearchResult) onChangeSelection; // Opción a futuro
  final bool isReserved;
  final VoidCallback onViewTicket;
  final Function(String)? onRemoveItem; // Nuevo callback para quitar items

  const UnifiedOrderCard({
    Key? key,
    required this.results,
    required this.onConfirmAll,
    required this.onChangeSelection,
    this.isReserved = false,
    required this.onViewTicket,
    this.onRemoveItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculamos total global
    double grandTotal = 0;
    for (var r in results) {
      grandTotal += r.totalPrice;
    }

    // SI ESTÁ RESERVADO: Mostrar tarjeta simplificada "Ver Ticket"
    if (isReserved) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HomeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomeColors.primary(context), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: HomeColors.shadowLight(context),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: HomeColors.primary(context),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              "Pedido Confirmado",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Tu pedido unificado está listo.",
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewTicket,
                icon: const Icon(
                  Icons.confirmation_number,
                  color: Colors.white,
                ),
                label: const Text(
                  "Ver Ticket Unificado",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeColors.primary(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomeColors.primary(context), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowLight(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomeColors.primary(context).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: HomeColors.primary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  "Resumen de Pedido",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),

          // Body: Lista de Bodegas
          ...results.map((bodega) => _buildBodegaSection(context, bodega)),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Estimado",
                      style: TextStyle(
                        fontSize: 16,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                    Text(
                      "S/ ${grandTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: HomeColors.primary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onConfirmAll,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: HomeColors.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Confirmar y Reservar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodegaSection(BuildContext context, BodegaSearchResult bodega) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: HomeColors.border(context).withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront,
                size: 18,
                color: HomeColors.textSecondary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bodega.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                "S/ ${bodega.totalPrice.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bodega.foundItems
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Row(
                    children: [
                      // Botón X para eliminar
                      if (onRemoveItem != null)
                        InkWell(
                          onTap: () => onRemoveItem!(item.name),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: HomeColors.error,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        "${item.requestedQuantity}x ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: HomeColors.primary(context),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: HomeColors.textSecondary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "S/ ${(item.price * item.requestedQuantity).toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 13,
                          color: HomeColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

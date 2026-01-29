import 'package:flutter/material.dart';
import '../home_colors.dart';
import '../../../models/search_models.dart'; // Para ProductItem

class BodegaCard extends StatelessWidget {
  final BodegaSearchResult bodega;
  final VoidCallback onViewMap;
  final VoidCallback onReserve;

  const BodegaCard({
    super.key,
    required this.bodega,
    required this.onViewMap,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowMedium(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // CABECERA DE LA BODEGA
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HomeColors.primaryLight(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: HomeColors.primary(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodega.name,
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: HomeColors.textMuted(context),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "A ${bodega.distanceMeters}m",
                            style: TextStyle(
                              color: HomeColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bodega.isOpen
                                  ? HomeColors.success.withOpacity(0.1)
                                  : HomeColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bodega.isOpen ? 'ABIERTO' : 'CERRADO',
                              style: TextStyle(
                                color: bodega.isOpen
                                    ? HomeColors.success
                                    : HomeColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio Total Resaltado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(
                        color: HomeColors.textMuted(context),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      "S/ ${bodega.totalPrice.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: HomeColors.primary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: HomeColors.divider(context)),

          // BOTÓN DE ACCIÓN ÚNICO (RESERVAR)
          InkWell(
            onTap: onReserve,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HomeColors.primary(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Confirmar Reserva y Ver Ticket",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(height: 1, color: HomeColors.divider(context)),

          // --- LISTA DE PRODUCTOS DETALLADA ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: bodega.foundItems.map((item) {
                final displayName = _formatItemName(item);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- COLUMNA IZQUIERDA: CANTIDAD ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.primary(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "x${item.requestedQuantity}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- COLUMNA CENTRAL: NOMBRE ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: HomeColors.textPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- COLUMNA DERECHA: PRECIO ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Mostramos precio unitario
                          Text(
                            "S/ ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: HomeColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Si quieres mostrar el subtotal (2 * 2.50 = 5.00) opcionalmente:
                          if (item.requestedQuantity > 1)
                            Text(
                              "Total: S/ ${(item.price * item.requestedQuantity).toStringAsFixed(2)}",
                              style: TextStyle(
                                color: HomeColors.textMuted(context),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatItemName(ProductItem item) {
    String fullName = item.name; // Ej: "Agua"
    final attrs = item.attributes;

    // 1. Marca
    if (attrs.containsKey('marca')) {
      fullName += ' ${attrs['marca']}'; // Ej: "Agua San Luis"
    }

    // 2. Gas (Lógica específica para bebidas)
    if (attrs.containsKey('gas')) {
      final val = attrs['gas'];
      // Maneja si viene como bool (true) o string ("true")
      bool hasGas = val == true || val.toString().toLowerCase() == 'true';
      fullName += hasGas ? ' con gas' : ' sin gas';
    }

    // 3. Capacidad / Volumen / Peso
    if (attrs.containsKey('capacidad')) {
      fullName += ' ${attrs['capacidad']}'; // Ej: "Agua San Luis sin gas 1L"
    } else if (attrs.containsKey('volumen')) {
      fullName += ' ${attrs['volumen']}';
    } else if (attrs.containsKey('peso')) {
      fullName += ' ${attrs['peso']}';
    }

    // 4. Otros detalles (Opcional: Color, Talla, etc.)
    attrs.forEach((key, value) {
      if (!['marca', 'gas', 'capacidad', 'volumen', 'peso'].contains(key)) {
        fullName += ' $value';
      }
    });

    return fullName;
  }
}

import 'package:flutter/material.dart';
import '../home_colors.dart';
import '../../../models/search_models.dart'; // Para ProductItem

class BodegaCard extends StatelessWidget {
  final BodegaSearchResult bodega;
  final VoidCallback onViewMap;
  final VoidCallback onReserve;
  final bool isReserved; // Nuevo

  const BodegaCard({
    super.key,
    required this.bodega,
    required this.onViewMap,
    required this.onReserve,
    this.isReserved = false,
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

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewMap,
                    icon: Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: HomeColors.primary(context),
                    ),
                    label: Text(
                      "Ver Mapa",
                      style: TextStyle(
                        color: HomeColors.primary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: HomeColors.primary(context).withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReserve,
                    icon: Icon(
                      isReserved
                          ? Icons.confirmation_number
                          : Icons.shopping_bag_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      isReserved ? "Ver mi ticket" : "Reservar",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: isReserved
                          ? Colors.green
                          : HomeColors.primary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- 1. CANTIDAD ---
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

                      // --- 2. IMAGEN DEL PRODUCTO (NUEVO) ---
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child:
                              item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildFallbackIcon(
                                      context,
                                      item.category,
                                    );
                                  },
                                )
                              : _buildFallbackIcon(context, item.category),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- 3. DETALLE ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: HomeColors.textPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.category != null)
                              Text(
                                item.category!,
                                style: TextStyle(
                                  color: HomeColors.textMuted(context),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // --- 4. PRECIO ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "S/ ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: HomeColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.requestedQuantity > 1)
                            Text(
                              "S/ ${(item.price * item.requestedQuantity).toStringAsFixed(2)}",
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

  Widget _buildFallbackIcon(BuildContext context, String? category) {
    // Mapas de iconos y colores por categoría
    final iconMap = {
      'Bebidas': Icons.local_drink,
      'Abarrotes': Icons.shopping_basket,
      'Limpieza': Icons.cleaning_services,
      'Cuidado Personal': Icons.face,
      'Snacks': Icons.fastfood,
      'Lácteos': Icons.egg_alt, // O algo similar si no existe
      'Frutas y Verduras': Icons.eco,
      'Carnes': Icons.restaurant,
      'Panadería': Icons.breakfast_dining,
      'Licores': Icons.wine_bar,
    };

    final colorMap = {
      'Bebidas': Colors.blue,
      'Abarrotes': Colors.orange,
      'Limpieza': Colors.teal,
      'Cuidado Personal': Colors.purple,
      'Snacks': Colors.amber,
      'Lácteos': Colors.lightBlue,
      'Frutas y Verduras': Colors.green,
      'Carnes': Colors.red,
      'Panadería': Colors.brown,
      'Licores': Colors.indigo,
    };

    final cat = category ?? 'Otros';
    final iconData = iconMap[cat] ?? Icons.category;
    final baseColor = colorMap[cat] ?? Colors.grey;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: baseColor.withOpacity(0.15),
      child: Icon(iconData, color: baseColor, size: 24),
    );
  }
}

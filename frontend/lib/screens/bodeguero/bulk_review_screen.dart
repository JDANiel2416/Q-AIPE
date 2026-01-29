import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/inventory_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'bodeguero_colors.dart';

class BulkReviewScreen extends StatefulWidget {
  final List<dynamic> products;

  const BulkReviewScreen({Key? key, required this.products}) : super(key: key);

  @override
  State<BulkReviewScreen> createState() => _BulkReviewScreenState();
}

class _BulkReviewScreenState extends State<BulkReviewScreen> {
  late List<Map<String, dynamic>> _validProducts;
  bool _isSaving = false;
  final ApiService _api = ApiService();

  // Cache local
  List<CategoryModel> _categories = [];
  final Map<int, List<SubCategoryModel>> _subCategoryCache = {};
  final Map<int, bool> _loadingSubCats = {};

  // Key para AnimatedList
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

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

    // Initial item setup
    _validProducts = widget.products
        .where((p) => (p['suggested_name'] ?? '').toString().isNotEmpty)
        .map((p) {
          final item = Map<String, dynamic>.from(p);

          // Normalizar string category (Legacy fallback)
          String catName = (item['category'] ?? '').toString().toUpperCase();
          String finalCat = 'Otros';

          if (catName.contains('BEBIDA'))
            finalCat = 'Bebidas';
          else if (catName.contains('ABARROTE'))
            finalCat = 'Abarrotes';
          else if (catName.contains('LIMPIEZA') || catName.contains('ASEO'))
            finalCat = 'Limpieza';

          item['category_name_legacy'] = finalCat; // String antiguo

          // Inicializar valores
          item['price'] ??= 0.0;
          item['stock'] ??= 1;
          item['attributes'] ??= <String, dynamic>{};
          if (item['attributes']['content'] == null) {
            item['attributes']['content'] = item['volume'] ?? '';
          }

          // Placeholders para modelos
          item['category_model'] = null;
          item['subcategory_model'] = null;

          return item;
        })
        .toList();

    // Cargar data real
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;

          // Match items to actual categories
          for (var item in _validProducts) {
            String legacyName = item['category_name_legacy'];
            String apiCatName = (item['category'] ?? '').toString();

            // 1. Intentar match exacto con el nombre que vino de la API (Prioridad Alta)
            CategoryModel? match = _categories.firstWhere(
              (c) => c.name.toUpperCase() == apiCatName.toUpperCase(),
              orElse: () =>
                  // 2. Fallback al legacy logic
                  _categories.firstWhere(
                    (c) => c.name.toUpperCase() == legacyName.toUpperCase(),
                    orElse: () => _categories.firstWhere(
                      (c) => c.name == 'Otros',
                      orElse: () => _categories.first,
                    ),
                  ),
            );

            item['category_model'] = match;
            // Cargar subcategorías iniciales
            _loadSubCategoriesFor(match.id);
          }
        });
      }
    } catch (e) {
      print("Error loading categories: $e");
    }
  }

  Future<void> _loadSubCategoriesFor(int categoryId) async {
    if (_subCategoryCache.containsKey(categoryId)) {
      _applySubCategoryMatch(categoryId);
      return;
    }
    if (_loadingSubCats[categoryId] == true) return;

    setState(() => _loadingSubCats[categoryId] = true);

    try {
      final subs = await _api.getSubCategories(categoryId);
      if (mounted) {
        setState(() {
          _subCategoryCache[categoryId] = subs;
          _loadingSubCats[categoryId] = false;
          _applySubCategoryMatch(categoryId);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSubCats[categoryId] = false);
    }
  }

  void _applySubCategoryMatch(int categoryId) {
    final subs = _subCategoryCache[categoryId] ?? [];
    if (subs.isEmpty) return;

    // Auto-select based on API result
    for (var item in _validProducts) {
      CategoryModel? cat = item['category_model'];
      if (cat != null && cat.id == categoryId) {
        // Si ya tiene algo seleccionado, no lo tocamos
        if (item['subcategory_model'] != null) continue;

        String? apiSubName =
            item['subcategory']; // Nombre que viene del JSON (ej: "Lácteos")

        if (apiSubName != null && apiSubName.isNotEmpty) {
          // Try exact match
          try {
            item['subcategory_model'] = subs.firstWhere(
              (s) => s.name.toUpperCase() == apiSubName.toUpperCase(),
            );
          } catch (e) {
            // No match found for specific string, default to first just in case
            item['subcategory_model'] = subs.first;
          }
        } else {
          // No sugerencia, default first
          item['subcategory_model'] = subs.first;
        }
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    // Validar
    final invalidItems = _validProducts.where((p) {
      final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
      final stock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
      return price <= 0 || stock <= 0;
    }).toList();

    if (invalidItems.isNotEmpty) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Corrija los productos con Precio S/ 0 o Stock 0"),
            backgroundColor: BColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    int successCount = 0;
    int failCount = 0;

    for (var p in _validProducts) {
      final attributes = p['attributes'] ?? {};
      String name = p['suggested_name'];

      // Data de modelos
      CategoryModel? catModel = p['category_model'];
      SubCategoryModel? subCatModel = p['subcategory_model'];

      String categoryName = catModel?.name ?? 'Otros';
      int? subCatId = subCatModel?.id;

      double price = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
      int stock = int.tryParse(p['stock']?.toString() ?? '1') ?? 1;

      final req = ProductCreateRequest(
        name: name,
        category: categoryName,
        subCategoryId: subCatId,
        price: price,
        stock: stock,
        attributes: attributes,
      );

      final res = await _api.addProduct(userId, req);
      if (res['success'])
        successCount++;
      else
        failCount++;
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? "✅ $successCount productos guardados correctamente"
                : "Guardados: $successCount | Errores: $failCount",
          ),
          backgroundColor: failCount == 0
              ? BColors.primary(context)
              : BColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (failCount == 0 && successCount > 0) {
        Navigator.pop(context, true);
      }
    }
  }

  void _removeProduct(int index) {
    if (index < 0 || index >= _validProducts.length) return;

    final removedItem = _validProducts[index];

    // 1. Remover de la lista visualmente con animación
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildRemovedItem(removedItem, animation),
      duration: const Duration(milliseconds: 400),
    );

    // 2. Remover de los datos
    _validProducts.removeAt(index);

    // Si queda vacío, redibujar para mostrar el "Empty State"
    if (_validProducts.isEmpty) {
      setState(() {}); // Trigger rebuild to show empty state
    }
  }

  // Widget para la animación de salida
  Widget _buildRemovedItem(
    Map<String, dynamic> item,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      axis: Axis.vertical,
      child: FadeTransition(
        opacity: animation,
        child: _buildProductCardRaw(
          item,
          isFunctionallyDisabled: true,
        ), // Reusar diseño
      ),
    );
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence) {
      case 'HIGH':
        return const Color(0xFF00E676);
      case 'MEDIUM':
        return const Color(0xFFFFAB40);
      case 'LOW':
        return const Color(0xFFFF5252);
      default:
        return Colors.grey;
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

            if (_validProducts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: BColors.textSecondary(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No se encontraron productos válidos",
                        style: TextStyle(
                          color: BColors.textSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  initialItemCount: _validProducts.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  itemBuilder: (context, index, animation) {
                    return _buildItemWithAnimation(index, animation);
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _validProducts.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 56,
                child: FloatingActionButton.extended(
                  onPressed: _isSaving ? null : _saveAll,
                  backgroundColor: BColors.primary(context),
                  elevation: 8,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 24),
                  label: Text(
                    _isSaving
                        ? "Guardando..."
                        : "Guardar Todo (${_validProducts.length})",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BColors.primaryLight(context).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: BColors.primary(context),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Revisar Productos",
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                if (_validProducts.isNotEmpty)
                  Text(
                    "${_validProducts.length} producto${_validProducts.length != 1 ? 's' : ''} detectado${_validProducts.length != 1 ? 's' : ''}",
                    style: TextStyle(
                      color: BColors.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWithAnimation(int index, Animation<double> animation) {
    if (index >= _validProducts.length) return const SizedBox();

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: _buildProductCard(index),
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final item = _validProducts[index];
    return _buildProductCardRaw(item, index: index);
  }

  Widget _buildProductCardRaw(
    Map<String, dynamic> item, {
    int? index,
    bool isFunctionallyDisabled = false,
  }) {
    String confidence = item['confidence'] ?? 'LOW';
    Color confidenceColor = _getConfidenceColor(confidence);

    CategoryModel? selectedCat = item['category_model'];
    List<SubCategoryModel> subCats = [];
    bool isLoadingSub = false;

    if (selectedCat != null) {
      subCats = _subCategoryCache[selectedCat.id] ?? [];
      isLoadingSub = _loadingSubCats[selectedCat.id] ?? false;
    }

    return Container(
      key: index != null ? ObjectKey(item) : null,
      margin: const EdgeInsets.only(bottom: 20),
      // ...Decoration...
      decoration: BoxDecoration(
        color: BColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: confidenceColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: BColors.shadowLight(context),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: confidenceColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        confidence == 'HIGH'
                            ? Icons.check_circle
                            : Icons.warning,
                        size: 14,
                        color: confidenceColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        confidence == 'HIGH' ? 'Alta Confianza' : 'Revisar',
                        style: TextStyle(
                          color: confidenceColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isFunctionallyDisabled && index != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: BColors.error),
                    onPressed: () => _removeProduct(index),
                    style: IconButton.styleFrom(
                      backgroundColor: BColors.error.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTextField(
                  initialValue: item['suggested_name']?.toString(),
                  label: "Nombre",
                  icon: Icons.inventory_2,
                  maxLines: 2,
                  onChanged: (val) => item['suggested_name'] = val,
                ),
                const SizedBox(height: 16),
                _buildCategoryDropdown(item, selectedCat),
                const SizedBox(height: 12),
                if (isLoadingSub)
                  const LinearProgressIndicator(minHeight: 2)
                else if (subCats.isNotEmpty)
                  _buildSubCategoryDropdown(item, subCats),
                const SizedBox(height: 16),
                _buildVolumeWithUnit(item),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        initialValue: item['price']?.toString(),
                        label: "Precio (S/)",
                        icon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) =>
                            item['price'] = double.tryParse(val) ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        initialValue: item['stock']?.toString(),
                        label: "Stock",
                        icon: Icons.inventory,
                        keyboardType: TextInputType.number,
                        onChanged: (val) =>
                            item['stock'] = int.tryParse(val) ?? 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(
    Map<String, dynamic> item,
    CategoryModel? selected,
  ) {
    return DropdownButtonFormField<CategoryModel>(
      value: selected,
      isExpanded: true,
      decoration: _inputDecoration("Categoría", Icons.category),
      style: TextStyle(
        color: BColors.textPrimary(context),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      dropdownColor: BColors.surface(context),
      icon: Icon(Icons.arrow_drop_down, color: BColors.primary(context)),
      items: _categories
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            item['category_model'] = val;
            item['subcategory_model'] = null; // Reset sub
            _loadSubCategoriesFor(val.id);
          });
        }
      },
    );
  }

  Widget _buildSubCategoryDropdown(
    Map<String, dynamic> item,
    List<SubCategoryModel> options,
  ) {
    return DropdownButtonFormField<SubCategoryModel>(
      value: item['subcategory_model'],
      isExpanded: true,
      decoration: _inputDecoration("Subcategoría", Icons.layers),
      style: TextStyle(
        color: BColors.textPrimary(context),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      dropdownColor: BColors.surface(context),
      icon: Icon(Icons.arrow_drop_down, color: BColors.primary(context)),
      items: options
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => item['subcategory_model'] = val);
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: BColors.textSecondary(context)),
      prefixIcon: Icon(icon, color: BColors.primary(context), size: 20),
      filled: true,
      fillColor: BColors.surfaceVariant(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: BColors.primary(context), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Mejorado: Mapeo amigable de unidades
  List<String> _getUnitsForCategory(String? categoryName) {
    // Internal keys: ml, L, kg, g, unidades
    final name = categoryName ?? 'Otros';
    switch (name) {
      case 'Bebidas':
        return ['ml', 'L'];
      case 'Limpieza':
        return ['ml', 'L', 'kg', 'g', 'unidades'];
      case 'Abarrotes':
        return ['kg', 'g', 'L', 'ml', 'unidades'];
      default:
        return ['unidades', 'ml', 'L', 'kg', 'g'];
    }
  }

  String _formatUnitDisplay(String unit) {
    switch (unit) {
      case 'kg':
        return 'KG (Kilogramos)';
      case 'g':
        return 'Gr (Gramos)';
      case 'L':
        return 'L (Litros)';
      case 'ml':
        return 'ml (Mililitros)';
      case 'unidades':
        return 'Ud. (Unidades)';
      default:
        return unit;
    }
  }

  Widget _buildVolumeWithUnit(Map<String, dynamic> item) {
    String content = item['attributes']['content']?.toString() ?? '';
    CategoryModel? cat = item['category_model'];
    List<String> validUnits = _getUnitsForCategory(cat?.name);

    String numericPart = '';
    String unitPart = validUnits.first;

    final match = RegExp(r'^([\d\.]+)\s*(.*)$').firstMatch(content);
    if (match != null) {
      numericPart = match.group(1) ?? '';
      String potentialUnit = match.group(2)?.trim() ?? '';
      // Intentar match con unidades validas
      final existing = validUnits.firstWhere(
        (u) => u.toLowerCase() == potentialUnit.toLowerCase(),
        orElse: () => '',
      );
      if (existing.isNotEmpty) unitPart = existing;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildTextField(
            initialValue: numericPart,
            label: "Cant/Peso",
            icon: Icons.onetwothree,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              numericPart = val;
              item['attributes']['content'] = "$numericPart $unitPart".trim();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3, // Más espacio para "KG (Kilogramos)"
          child: DropdownButtonFormField<String>(
            value: unitPart,
            isExpanded: true,
            decoration: _inputDecoration("Unidad", Icons.straighten),
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            dropdownColor: BColors.surface(context),
            icon: Icon(Icons.arrow_drop_down, color: BColors.primary(context)),
            items: validUnits
                .map(
                  (u) => DropdownMenuItem(
                    value: u,
                    child: Text(
                      _formatUnitDisplay(u),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  unitPart = val;
                  item['attributes']['content'] = "$numericPart $unitPart"
                      .trim();
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    String? initialValue,
    required String label,
    required IconData icon,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        color: BColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      cursorColor: BColors.primary(context),
      decoration: _inputDecoration(label, icon).copyWith(hintText: hintText),
      onChanged: onChanged,
    );
  }
}

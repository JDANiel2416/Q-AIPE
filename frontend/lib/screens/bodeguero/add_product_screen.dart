// lib/screens/add_product_screen.dart
import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import 'package:flutter/services.dart';

import 'bodeguero_colors.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'bulk_review_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _isLoading = false;
  bool _isScanning = false; // Estado para el loading del escaneo

  // Controladores básicos
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();

  // Estado para campos dinámicos
  CategoryModel? _selectedCategory;
  SubCategoryModel? _selectedSubCategory; // Nuevo: Objeto SubCategoría
  String _selectedUnit = 'ml'; // Restaurado

  // Controladores para atributos específicos
  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _contentCtrl =
      TextEditingController(); // Unificado: Capacidad/Peso/Cantidad
  bool _hasGas = false;

  List<CategoryModel> _categories = [];
  List<SubCategoryModel> _subCategories = []; // Dinámica del backend

  // Mapas de configuración
  // _subCategories hardcoded REMOVIDO en favor de Backend

  final Map<String, List<String>> _unitsByCategory = {
    'Bebidas': ['ml', 'L'],
    'Limpieza': ['ml', 'L', 'kg', 'g', 'unidades'],
    'Abarrotes': ['kg', 'g', 'L', 'ml', 'unidades'],
    'Otros': ['unidades'],
  };

  // Marcas comunes Perú
  String? _selectedBrandPredefined;
  final Map<String, List<String>> _brandsBySubCategory = {
    // Agua
    'Agua': [
      'Cielo',
      'San Luis',
      'San Mateo',
      'Loa',
      'Vida',
      'Socosani',
      'Otras',
    ],
    // Gaseosa
    'Gaseosa': [
      'Inca Kola',
      'Coca-Cola',
      'Sprite',
      'Fanta',
      'Pepsi',
      'Seven Up',
      'Kola Real',
      'Big Cola',
      'Otras',
    ],
    // Cerveza
    'Cerveza': [
      'Pilsen Callao',
      'Pilsen Trujillo',
      'Cusqueña',
      'Cristal',
      'Arequipeña',
      'Corona',
      'Heineken',
      'Otras',
    ],
    // Limpieza
    'Detergente': ['Bolívar', 'Ariel', 'Opal', 'Ace', 'Marsella', 'Otras'],
    'Jabón': ['Bolívar', 'Marsella', 'Protex', 'Lux', 'Camay', 'Otras'],
    'Lejía': ['Clorox', 'Sapolio', 'Otras'],
    // Abarrotes comunes
    'Arroz': ['Costeño', 'Paisana', 'Faraón', 'Valle Norte', 'Otras'],
    'Aceite': ['Primor', 'Cocinero', 'Cil', 'Sao', 'Otras'],
    'Leche': [
      'Gloria',
      'Laive',
      'Ideal',
      'Pura Vida',
      'Otras',
    ], // Si hubiera subcategoría Leche
    'Fideos': ['Don Vittorio', 'Molitalia', 'Anita', 'Lavaggi', 'Otras'],
  };

  bool _isLoadingSubCategories = false; // Estado de carga para subcategorías

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _api.getCategories();
    if (mounted) {
      setState(() {
        if (cats.isNotEmpty) {
          _categories = cats;
          // Set default if None selected or restore
          if (_selectedCategory == null ||
              !_categories.any((c) => c.id == _selectedCategory?.id)) {
            _selectedCategory = _categories.first;
          }
        } else {
          // Fallback vacío, pero no strings
          _categories = [];
        }
        _updateDefaults();
      });
    }
  }

  Future<void> _loadSubCategories() async {
    if (_selectedCategory == null) {
      setState(() => _subCategories = []);
      return;
    }

    setState(() {
      _isLoadingSubCategories = true; // Bloqueo de UI
    });

    try {
      final subs = await _api.getSubCategories(_selectedCategory!.id);
      if (mounted) {
        setState(() {
          _subCategories = subs;
          // Auto select first subcategory
          if (_subCategories.isNotEmpty) {
            _selectedSubCategory = _subCategories.first;
          } else {
            _selectedSubCategory = null;
          }
          // Update dependent logic
          _updateDefaultsAfterSubCat();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSubCategories = false; // Desbloqueo
        });
      }
    }
  }

  void _updateDefaults() {
    // Al cambiar CATEGORÍA, cargamos SUBCATEGORÍAS
    _loadSubCategories();

    // Y reseteamos unidades por defecto basado en el nombre de la categoría (Legacy logic preserved)
    setState(() {
      String catName = _selectedCategory?.name ?? "";
      _selectedUnit = _unitsByCategory[catName]?.first ?? 'unidades';

      // Si no encuentra match exacto, usar default units
      if (_unitsByCategory[catName] == null) {
        // Lógica difusa
        if (catName == 'Bebidas')
          _selectedUnit = 'ml';
        else if (catName == 'Abarrotes')
          _selectedUnit = 'kg';
        else
          _selectedUnit = 'unidades';
      }
    });
  }

  void _updateDefaultsAfterSubCat() {
    // Resetear marca
    _selectedBrandPredefined = null;
    _brandCtrl.clear();

    // Lógica por defecto para gas
    if (_selectedCategory?.name == 'Bebidas') {
      _updateGasLogic();
    }
  }

  void _updateGasLogic() {
    if (_selectedCategory?.name != 'Bebidas') return;

    String subName = _selectedSubCategory?.name ?? "";

    // Lógica automática para gas
    switch (subName) {
      case 'Gaseosa':
      case 'Gaseosas':
      case 'Cerveza':
      case 'Cervezas':
      case 'Energizante':
      case 'Energizantes':
        _hasGas = true;
        break;
      case 'Agua':
        _hasGas = false;
        break;
      default:
        _hasGas = false;
    }
  }

  // Getter para nombre computado
  String get _computedName {
    if (_selectedCategory?.name == 'Otros') return _nameCtrl.text;
    String sub = _selectedSubCategory?.name ?? '';

    // Usar marca predefinida si existe y no es "Otras", sino usar el campo manual
    String brand = _brandCtrl.text;
    if (_selectedBrandPredefined != null &&
        _selectedBrandPredefined != 'Otras') {
      brand = _selectedBrandPredefined!;
    }

    String content = _contentCtrl.text;
    String unit = _selectedUnit;

    // Si estamos en modo manual ("Otras" o sin lista), validamos que haya escrito algo
    if ((_selectedBrandPredefined == null ||
            _selectedBrandPredefined == 'Otras') &&
        brand.isEmpty) {
      return "Complete la marca...";
    }

    if (content.isEmpty) return "$sub $brand";

    return "$sub $brand $content $unit";
  }

  // --- LÓGICA DE ESCANEO IA ---
  Future<void> _scanWithAI() async {
    final picker = ImagePicker();
    // 1. Capturar foto
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile == null) return; // Cancelado por usuario

    setState(() => _isScanning = true);

    // 2. Enviar al backend
    final result = await _api.scanMagicProduct(File(pickedFile.path));

    setState(() => _isScanning = false);

    if (result['success']) {
      final aiData = result['ai_data'];
      final int? masterId = result['found_master_id'];

      if (aiData == null) return;

      // 3. Validar contenido inapropiado o irrelevante
      bool isValid =
          aiData['is_valid'] ?? true; // Backward compatibility default true
      if (!isValid) {
        String reason =
            aiData['reason'] ?? "La imagen no muestra un producto válido.";

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1F2E),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text(
                    "Imagen No Válida",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Text(
                reason,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Entendido",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _scanWithAI(); // Reintentar inmediatamente
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BColors.primary(context),
                  ),
                  child: const Text("Intentar de nuevo"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 4. Mapear datos si es válido
      _populateFromAI(aiData, masterId);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error IA: ${result['message']}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- ESCANEO MASIVO ---
  Future<void> _scanBulkWithAI() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isScanning = true);

    final result = await _api.scanBulkProducts(File(pickedFile.path));

    setState(() => _isScanning = false);

    if (result.containsKey('products')) {
      final List<dynamic> products = result['products'];
      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se detectaron productos")),
          );
        }
        return;
      }

      if (mounted) {
        // Navegar a la pantalla de revisión
        // Necesitamos importar bulk_review_screen.dart al inicio del archivo
        // Como no puedo añadir imports fácilmente sin arruinar el resto, usaré ruta nombrada o import dinámico simulado
        // Asumo que el user prefirio crear una nueva pantalla.
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BulkReviewScreen(products: products),
          ),
        );

        if (mounted && result == true) {
          Navigator.pop(context, true);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${result['message']}")));
      }
    }
  }

  void _populateFromAI(Map<String, dynamic> data, int? masterId) {
    // data keywords: explicit keys from backend prompt
    // check gemini_service.py: suggested_name, brand, category, volume, is_alcoholic

    // 1. Determine Category Name Target
    String rawCat = (data['category'] ?? "Otros").toString().toUpperCase();
    String targetCatName = 'Otros';

    if (rawCat.contains("BEBIDA") ||
        rawCat.contains("GASEOSA") ||
        rawCat.contains("CERVEZA")) {
      targetCatName = 'Bebidas';
    } else if (rawCat.contains("LIMPIEZA") || rawCat.contains("ASEO")) {
      targetCatName = 'Limpieza';
    } else if (rawCat.contains("ABARROTE") ||
        rawCat.contains("ALIMENTO") ||
        rawCat.contains("SNACK")) {
      targetCatName = 'Abarrotes';
    }

    setState(() {
      // 2. Set Category Object
      try {
        _selectedCategory = _categories.firstWhere(
          (c) => c.name.toUpperCase() == targetCatName.toUpperCase(),
          orElse: () => _categories.first,
        );
      } catch (e) {
        if (_categories.isNotEmpty) _selectedCategory = _categories.first;
      }

      // 3. Set Unit Default
      _selectedUnit =
          _unitsByCategory[_selectedCategory?.name]?.first ?? 'unidades';

      // 4. Reset SubCat and Load Async
      _selectedSubCategory = null;
    });

    // 5. Load Subcategories Async
    _loadSubCategories().then((_) {
      if (!mounted) return;

      String? aiSub = (data['subcategory'] as String?);
      SubCategoryModel? matchedSub;

      if (aiSub != null) {
        try {
          // Try exact match
          matchedSub = _subCategories.firstWhere(
            (s) => s.name.toUpperCase() == aiSub.toUpperCase(),
          );
        } catch (_) {
          // Fallback: Fuzzy search
          try {
            matchedSub = _subCategories.firstWhere(
              (s) => (data['suggested_name'] ?? "")
                  .toString()
                  .toUpperCase()
                  .contains(s.name.toUpperCase()),
            );
          } catch (__) {}
        }
      }

      setState(() {
        if (matchedSub != null) {
          _selectedSubCategory = matchedSub;
        } else {
          // Default to first if available (already handled in _loadSubCategories but good to be sure)
          if (_subCategories.isNotEmpty && _selectedSubCategory == null) {
            _selectedSubCategory = _subCategories.first;
          }
        }

        // 6. Update dependent logic (Gas, Brand)
        _updateDefaultsAfterSubCat();

        // 7. Set Brand (Async part)
        String aiBrand = (data['brand'] ?? "").toString();
        if (aiBrand.isNotEmpty) {
          // Check if predefined
          String? subName = _selectedSubCategory?.name;
          if (subName != null && _brandsBySubCategory.containsKey(subName)) {
            // Try to match
            try {
              String matchedBrand = _brandsBySubCategory[subName]!.firstWhere(
                (b) =>
                    b.toUpperCase() == aiBrand.toUpperCase() ||
                    aiBrand.toUpperCase().contains(b.toUpperCase()),
              );
              _selectedBrandPredefined = matchedBrand;
              _brandCtrl.text = matchedBrand;
            } catch (_) {
              _selectedBrandPredefined = 'Otras';
              _brandCtrl.text = aiBrand;
            }
          } else {
            // No predefined brands for this subcat
            _selectedBrandPredefined = null;
            _brandCtrl.text = aiBrand;
          }
        }
      });
    });

    setState(() {
      // 8. Other Fields (Sync)
      String volume = (data['volume'] ?? "").toString();
      _parseVolume(volume);

      if (_selectedCategory?.name == 'Otros') {
        _nameCtrl.text = data['suggested_name'] ?? "";
      }
    });

    // Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          masterId != null
              ? '¡Producto identificado en el sistema! ✨'
              : 'Datos extraídos de la etiqueta 📷',
        ),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _parseVolume(String volStr) {
    if (volStr.isEmpty) return;
    final regex = RegExp(r'(\d+(\.\d+)?)\s*([a-zA-Z]+)');
    final match = regex.firstMatch(volStr);

    if (match != null) {
      String qty = match.group(1) ?? ""; // "500"
      String unit = (match.group(3) ?? "").toLowerCase(); // "ml"

      _contentCtrl.text = qty;

      // Normalizar unidad
      if (unit == "l" || unit == "lt" || unit == "litros")
        _selectedUnit = "L";
      else if (unit == "ml")
        _selectedUnit = "ml";
      else if (unit == "kg" || unit == "kilos")
        _selectedUnit = "kg";
      else if (unit == "g" || unit == "gr")
        _selectedUnit = "g";

      // Verificar que la unidad exista en la categoría actual
      List<String> validUnits = _unitsByCategory[_selectedCategory] ?? [];
      if (!validUnits.contains(_selectedUnit)) {
        _selectedUnit = validUnits.first; // Fallback
      }
    } else {
      // Si no se pudo parsear, poner todo en el texto
      _contentCtrl.text = volStr;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    Map<String, dynamic> dynamicAttributes = {
      "marca": _brandCtrl.text,
      if (_selectedSubCategory != null) "tipo": _selectedSubCategory,
    };

    // Construir atributos según categoría
    if (_selectedCategory == 'Bebidas') {
      dynamicAttributes["capacidad"] = "${_contentCtrl.text} $_selectedUnit";

      // Solo guardar 'gas' si es relevante o si es Agua (donde es opcional)
      if (_selectedSubCategory == 'Agua' ||
          _selectedSubCategory == 'Gaseosa' ||
          _selectedSubCategory == 'Energizante') {
        dynamicAttributes["gas"] = _hasGas;
      }
      // Para otros (Jugo, Rehidratante, Licor) asumimos sin gas usualmente o no relevante,
      // pero si el usuario quiere guardarlo para todo, podemos dejarlo.
      // Según requerimiento: "gaseosas siempre tienen gas... jugos nunca".
      // Vamos a guardar la propiedad 'gas' explícitamente solo para Agua,
      // para los demás, se puede inferir del tipo, pero lo guardaremos si es TRUE para consistencia.
      if (_hasGas && _selectedSubCategory != 'Agua') {
        dynamicAttributes["gas"] = true;
      }
      // Específicamente para Agua, guardamos el false también para distinguir "Con Gas" / "Sin Gas"
      if (_selectedSubCategory == 'Agua') {
        dynamicAttributes["gas"] = _hasGas;
      }
    } else if (_selectedCategory == 'Limpieza' ||
        _selectedCategory == 'Abarrotes') {
      dynamicAttributes["contenido_neto"] =
          "${_contentCtrl.text} $_selectedUnit";
    } else {
      dynamicAttributes["detalle"] = _contentCtrl.text.isNotEmpty
          ? "${_contentCtrl.text} $_selectedUnit"
          : "N/A";
    }

    final newProduct = ProductCreateRequest(
      name: _computedName,
      category: _selectedCategory!
          .name, // Mandamos string al backend (backward compat)
      subCategoryId: _selectedSubCategory?.id, // Mandamos ID nuevo
      price: double.parse(_priceCtrl.text),
      stock: int.parse(_stockCtrl.text),
      attributes: dynamicAttributes,
    );

    final result = await _api.addProduct(userId, newProduct);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto agregado correctamente 📦'),
            backgroundColor: BColors.primary(context),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        if (result['status'] == 409) {
          // ALERTA DE DUPLICADO
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1F2E),
              title: Text(
                "Producto Existente",
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                result['message'] ?? "Este producto ya está en tu lista.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Cerrar primer diálogo
                    _showUpdateConfirmation(); // Mostrar confirmación
                  },
                  child: Text(
                    "Modificar Producto",
                    style: TextStyle(
                      color: Color(0xFF00D9FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showUpdateConfirmation() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: Text(
          "Confirmar Actualización",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Deseas actualizar el producto existente con estos nuevos datos?",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              "Precio: S/ ${_priceCtrl.text}",
              style: TextStyle(
                color: BColors.primary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Stock: ${_stockCtrl.text}",
              style: TextStyle(
                color: BColors.primary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cerrar diálogo de confirmación
              await _performUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: Text(
              "Confirmar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpdate() async {
    setState(() => _isLoading = true);

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    final result = await _api.updateProduct(
      userId,
      _computedName, // Usamos el nombre generado
      _selectedCategory!.name,
      double.parse(_priceCtrl.text),
      int.parse(_stockCtrl.text),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto actualizado correctamente ✅'),
            backgroundColor: BColors.primary(context),
          ),
        );
        Navigator.pop(context, true); // Volver a la pantalla anterior
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildDynamicFields() {
    List<Widget> fields = [];

    // Dropdown de Subcategoría (Tipo)
    // Si tenemos subcategorías cargadas    // LOADING STATE OVERLAY
    if (_isLoadingSubCategories) {
      return SizedBox(
        height: 160, // Altura ajustada
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: BColors.primary(context)),
              const SizedBox(height: 16),
              Text(
                "Cargando opciones de ${_selectedCategory?.name}...",
                style: TextStyle(
                  color: BColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedSubCategory != null && _subCategories.isNotEmpty) {
      // Dropdown de Subcategoría
      fields.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: BColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButtonFormField<SubCategoryModel>(
              value: _selectedSubCategory,
              items: _subCategories
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.name,
                        style: TextStyle(color: BColors.textPrimary(context)),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSubCategory = val;
                  // Update dependent logic
                  _updateDefaultsAfterSubCat();
                  _updateGasLogic();
                });
              },
              dropdownColor: BColors.surface(context),
              decoration: InputDecoration(
                labelText: _selectedCategory != null
                    ? "Tipo de ${_selectedCategory!.name}"
                    : "Tipo",
                labelStyle: TextStyle(color: BColors.textSecondary(context)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(color: BColors.textPrimary(context)),
              iconEnabledColor: BColors.primary(context),
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // LOGICA MARCAS: Dropdown vs Texto Manual
    String? subName = _selectedSubCategory?.name;
    bool hasPredefinedBrands =
        subName != null && _brandsBySubCategory.containsKey(subName);

    if (hasPredefinedBrands) {
      // Dropdown de Marcas
      fields.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: BColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButtonFormField<String>(
              value: _selectedBrandPredefined,
              items: _brandsBySubCategory[subName]!
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(
                        b,
                        style: TextStyle(color: BColors.textPrimary(context)),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedBrandPredefined = val;
                  if (val == 'Otras') {
                    _brandCtrl.clear();
                  } else {
                    _brandCtrl.text = val!;
                  }
                });
              },
              dropdownColor: BColors.surface(context),
              decoration: InputDecoration(
                labelText: "Seleccionar Marca",
                labelStyle: TextStyle(color: BColors.textSecondary(context)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(color: BColors.textPrimary(context)),
              iconEnabledColor: BColors.primary(context),
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Campo de Texto Manual (Si no hay lista o seleccionó "Otras")
    if (!hasPredefinedBrands || _selectedBrandPredefined == 'Otras') {
      fields.add(
        _buildTextField(
          controller: _brandCtrl,
          label: hasPredefinedBrands
              ? 'Especifique la marca'
              : 'Marca / Fabricante',
          validator: (v) => v!.isEmpty ? "Requerido" : null,
        ),
      );
      fields.add(const SizedBox(height: 12));
    } else {
      // Espacio si solo mostramos dropdown
      fields.add(const SizedBox(height: 12));
    }

    // Campo de Cantidad + Unidad
    if (_selectedCategory != null && _selectedCategory!.name != 'Otros') {
      List<String> unitItems =
          _unitsByCategory[_selectedCategory!.name] ?? ['unidades'];

      // Validation to prevent crash: Ensure _selectedUnit is in the list
      if (!unitItems.contains(_selectedUnit)) {
        _selectedUnit = unitItems.first;
      }

      fields.add(
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _contentCtrl,
                label: 'Contenido', // "Capacidad" o "Peso" o "Cantidad"
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: BColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    isExpanded: true, // Prevent overflow
                    isDense: true, // Compact
                    items: unitItems
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              u,
                              style: TextStyle(
                                color: BColors.textPrimary(context),
                                fontSize: 13, // Slightly smaller
                              ),
                              overflow: TextOverflow.ellipsis, // Safety
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedUnit = val!),
                    dropdownColor: BColors.surface(context),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, // Reduced
                        vertical: 14, // Reduced
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(color: BColors.textPrimary(context)),
                    iconEnabledColor: BColors.primary(context),
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Checkbox de GAS
    if (_selectedCategory == 'Bebidas' && _selectedSubCategory == 'Agua') {
      fields.add(const SizedBox(height: 12));
      fields.add(
        Container(
          decoration: BoxDecoration(
            color: BColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            title: Text(
              "¿Con Gas?",
              style: TextStyle(color: BColors.textPrimary(context)),
            ),
            value: _hasGas,
            onChanged: (v) => setState(() => _hasGas = v!),
            activeColor: BColors.primary(context),
            checkColor: Colors.white,
          ),
        ),
      );
    }

    return Column(children: fields);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: BColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      cursorColor: BColors.primary(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: BColors.textSecondary(context)),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BColors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Datos Básicos",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: BColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BOTONES DE IA (Fila)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            // Botón Simple
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isScanning ? null : _scanWithAI,
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt_outlined),
                                label: const Text("1 Prod."),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Botón Masivo
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isScanning ? null : _scanBulkWithAI,
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.burst_mode),
                                label: const Text("Masivo"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFF00C853,
                                  ), // Verde para diferenciar
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dropdown de categoría
                      Container(
                        decoration: BoxDecoration(
                          color: BColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButtonFormField<CategoryModel>(
                            value: _selectedCategory,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        color: BColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val;
                                _updateDefaults();
                              });
                            },
                            dropdownColor: BColors.surface(context),
                            decoration: InputDecoration(
                              labelText: "Categoría",
                              labelStyle: TextStyle(
                                color: BColors.textSecondary(context),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            style: TextStyle(
                              color: BColors.textPrimary(context),
                            ),
                            iconEnabledColor: BColors.primary(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Lógica de Nombre Automático vs Manual
                      if (_selectedCategory == 'Otros') ...[
                        _buildTextField(
                          controller: _nameCtrl,
                          label: "Nombre del Producto",
                          validator: (v) =>
                              v!.isEmpty ? "Campo obligatorio" : null,
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Para categorías estructuradas, sin campo de nombre
                        const SizedBox(height: 0),
                      ],

                      // Sección de detalles específicos
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: BColors.primary(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Detalles de ${_selectedCategory?.name ?? 'Categoría'}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: BColors.primary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: BColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: BColors.shadowLight(context),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: BColors.border(context),
                            width: 0.5,
                          ),
                        ),
                        child: _buildDynamicFields(),
                      ),

                      const SizedBox(height: 24),

                      // Precio y Stock (ahora después de los detalles)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceCtrl,
                              label: "Precio (S/)",
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? "Requerido" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _stockCtrl,
                              label: "Stock Inicial",
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? "Requerido" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Botón de guardar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: BColors.primary(
                              context,
                            ).withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Guardar Producto",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
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
          Text(
            "Nuevo Producto",
            style: TextStyle(
              color: BColors.textPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

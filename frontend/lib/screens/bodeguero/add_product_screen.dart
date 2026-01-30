// lib/screens/add_product_screen.dart
import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import 'package:flutter/services.dart';

import 'bodeguero_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'bulk_review_screen.dart';

import 'dart:io';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isEditMode;

  const AddProductScreen({
    super.key,
    this.initialData,
    this.isEditMode = false,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  // Atributos Granulares
  bool _sugarFree = false;
  bool _lactoseFree = false;
  final TextEditingController _flavorCtrl = TextEditingController();

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

  int? _selectedMasterId;

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
  Future<String?> _scanWithAI() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 800,
    );

    if (pickedFile == null) return null;

    setState(() => _isScanning = true);

    File imageFile = File(pickedFile.path);

    try {
      final result = await _api.scanBulkProducts(imageFile);

      setState(() => _isScanning = false);

      if (result['error'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? "Error desconocido")),
          );
        }
        return null;
      }

      final List<dynamic> products = result['products'] ?? [];

      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se detectaron productos")),
          );
        }
        return null;
      }

      if (products.length == 1) {
        // CASO 1: Un solo producto -> Populate
        Map<String, dynamic> aiData = products[0];
        _selectedMasterId = null;
        _populateFromAI(aiData, null);
        return aiData['suggested_name'];
      } else {
        // CASO 2: Múltiples -> Pantalla de Revisión Masiva
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BulkReviewScreen(products: products),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
      return null;
    }
  }

  // --- HELPER PARA AUTOCOMPLETE ---
  void _fillFormFromMaster(Map<String, dynamic> masterData) {
    setState(() {
      _selectedMasterId = masterData['id'];
    });

    final attrs = masterData['attributes'] ?? {};

    Map<String, dynamic> aiFormat = {
      "suggested_name": masterData['name'],
      "product_category": masterData['category'],
      "subcategory": masterData['subcategory'],
      "brand": attrs['marca'],
      "volume":
          attrs['contenido_neto'] ??
          attrs['capacidad'] ??
          attrs['detalle'] ??
          "",
      "attributes": attrs,
      "derived_attributes": {},
    };

    _populateFromAI(aiFormat, masterData['id']);
  }

  void _populateFromAI(Map<String, dynamic> data, int? masterId) {
    // data keywords: explicit keys from backend prompt
    // check gemini_service.py: suggested_name, brand, category, volume, is_alcoholic

    // 1. Determine Category Name Target
    String rawCat = (data['product_category'] ?? data['category'] ?? "Otros")
        .toString();
    String targetCatName = 'Otros';

    // Primary Strategy: Strict Match against loaded categories
    try {
      var directMatch = _categories.firstWhere(
        (c) => c.name.toUpperCase() == rawCat.toUpperCase(),
      );
      targetCatName = directMatch.name;
    } catch (_) {
      // Secondary Strategy: Heuristic keywords
      String upRaw = rawCat.toUpperCase();
      if (upRaw.contains("BEBIDA") ||
          upRaw.contains("GASEOSA") ||
          upRaw.contains("CERVEZA") ||
          upRaw.contains("ALCOHOL")) {
        targetCatName = 'Bebidas';
      } else if (upRaw.contains("LIMPIEZA") || upRaw.contains("ASEO")) {
        targetCatName = 'Limpieza';
      } else if (upRaw.contains("ABARROTE") ||
          upRaw.contains("ALIMENTO") ||
          upRaw.contains("SNACK") ||
          upRaw.contains("Abarrotes")) {
        // Added explicit Abarrotes check in case of plural diff
        targetCatName = 'Abarrotes';
      } else if (upRaw.contains("MASCOTA")) {
        targetCatName = 'Mascotas';
      } else if (upRaw.contains("PERSONAL") || upRaw.contains("CUIDADO")) {
        targetCatName = 'Cuidado Personal';
      }
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
          String? subName = _selectedSubCategory?.name;
          if (subName != null && _brandsBySubCategory.containsKey(subName)) {
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
            _selectedBrandPredefined = null;
            _brandCtrl.text = aiBrand;
          }
        }

        // 9. Granular Attributes (Moved here to run AFTER defaults reset)
        final attrs = data['attributes'] ?? {};

        // GAS logic override
        if (attrs['has_gas'] != null) {
          _hasGas = attrs['has_gas'] == true;
        }

        if (attrs['sugar_free'] == true) _sugarFree = true;
        if (attrs['lactose_free'] == true) _lactoseFree = true;

        if (attrs['flavor'] != null) {
          _flavorCtrl.text = attrs['flavor'].toString();
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
      if (_selectedSubCategory != null) "tipo": _selectedSubCategory?.name,
    };

    // Construir atributos según categoría
    if (_selectedCategory?.name == 'Bebidas') {
      dynamicAttributes["capacidad"] = "${_contentCtrl.text} $_selectedUnit";

      // Solo guardar 'gas' si es relevante o si es Agua (donde es opcional)
      if (_selectedSubCategory?.name == 'Agua' ||
          _selectedSubCategory?.name == 'Gaseosa' ||
          _selectedSubCategory?.name == 'Energizante') {
        dynamicAttributes["gas"] = _hasGas;
      }
      // Para otros (Jugo, Rehidratante, Licor) asumimos sin gas usualmente o no relevante,
      // pero si el usuario quiere guardarlo para todo, podemos dejarlo.
      // Según requerimiento: "gaseosas siempre tienen gas... jugos nunca".
      // Vamos a guardar la propiedad 'gas' explícitamente solo para Agua,
      // para los demás, se puede inferir del tipo, pero lo guardaremos si es TRUE para consistencia.
      if (_hasGas && _selectedSubCategory?.name != 'Agua') {
        dynamicAttributes["gas"] = true;
      }
      // Específicamente para Agua, guardamos el false también para distinguir "Con Gas" / "Sin Gas"
      if (_selectedSubCategory?.name == 'Agua') {
        dynamicAttributes["gas"] = _hasGas;
      }
    } else if (_selectedCategory?.name == 'Limpieza' ||
        _selectedCategory?.name == 'Abarrotes') {
      dynamicAttributes["contenido_neto"] =
          "${_contentCtrl.text} $_selectedUnit";

      // Lácteos logic
      if (_selectedSubCategory?.name.contains('Leche') == true ||
          _selectedSubCategory?.name.contains('Yogurt') == true) {
        if (_lactoseFree) dynamicAttributes["sin_lactosa"] = true;
        if (_flavorCtrl.text.isNotEmpty)
          dynamicAttributes["sabor"] = _flavorCtrl.text;
      }

      // Golosinas / Snacks / Jugos (Abarrotes/Bebidas overlap depending on taxonomy)
      if (_flavorCtrl.text.isNotEmpty)
        dynamicAttributes["sabor"] = _flavorCtrl.text;
    } else {
      dynamicAttributes["detalle"] = _contentCtrl.text.isNotEmpty
          ? "${_contentCtrl.text} $_selectedUnit"
          : "N/A";
    }

    // Common optional attributes
    if (_sugarFree) dynamicAttributes["sin_azucar"] = true;
    if (_flavorCtrl.text.isNotEmpty &&
        !dynamicAttributes.containsKey("sabor")) {
      dynamicAttributes["sabor"] = _flavorCtrl.text;
    }

    final newProduct = ProductCreateRequest(
      name: _computedName,
      category: _selectedCategory!.name,
      subCategoryId: _selectedSubCategory?.id,
      masterProductId: _selectedMasterId, // NUEVO: Enviar Master ID
      price: double.parse(_priceCtrl.text),
      stock: int.parse(_stockCtrl.text),
      attributes: dynamicAttributes,
    );

    final result = await _api.addProduct(userId, newProduct);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Producto agregado correctamente ✅")),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        if (result['status'] == 409) {
          _showUpdateConfirmation(conflictId: result['product_id']);
          return;
        }

        // Diferenciar errores
        bool isSafety =
            (result['message'] ?? "").toString().contains("seguridad") ||
            result['status'] == 400;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Error desconocido"),
            backgroundColor: isSafety ? Colors.red : Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return; // Stop execution
    }
  }

  void _showUpdateConfirmation({int? conflictId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Producto existente"),
        content: const Text(
          "Este producto ya existe en tu inventario. ¿Deseas actualizar el stock y el precio con los datos ingresados?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performUpdate(conflictId: conflictId);
            },
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpdate({int? conflictId}) async {
    final userId = await SessionService().getUserId();
    if (userId == null) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> result;
    int? targetId = conflictId ?? _selectedMasterId;

    if (targetId != null) {
      result = await _api.updateProductStock(
        userId,
        targetId,
        double.parse(_priceCtrl.text),
        int.parse(_stockCtrl.text),
      );
    } else {
      result = await _api.updateProduct(
        userId,
        _computedName,
        _selectedCategory!.name,
        double.parse(_priceCtrl.text),
        int.parse(_stockCtrl.text),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Producto actualizado correctamente"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Error al actualizar"),
            backgroundColor: Colors.red,
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
    if (_selectedCategory?.name == 'Bebidas' &&
        _selectedSubCategory?.name == 'Agua') {
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

    // --- NUEVOS ATRIBUTOS GRANULARES ---

    if (_shouldShowFlavor()) {
      fields.add(const SizedBox(height: 12));
      fields.add(
        Container(
          decoration: BoxDecoration(
            color: BColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _flavorCtrl,
            style: TextStyle(color: BColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: "Sabor / Variedad",
              hintStyle: TextStyle(color: BColors.textSecondary(context)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.incomplete_circle,
                color: BColors.textSecondary(context),
              ),
            ),
          ),
        ),
      );
    }

    if (_shouldShowSugarFree()) {
      fields.add(const SizedBox(height: 8));
      fields.add(
        SwitchListTile(
          title: Text(
            "Sin Azúcar / Zero",
            style: TextStyle(color: BColors.textPrimary(context)),
          ),
          value: _sugarFree,
          onChanged: (val) => setState(() => _sugarFree = val),
          activeColor: BColors.primary(context),
          contentPadding: EdgeInsets.symmetric(horizontal: 4),
        ),
      );
    }

    if (_shouldShowLactoseFree()) {
      fields.add(const SizedBox(height: 8));
      fields.add(
        SwitchListTile(
          title: Text(
            "Sin Lactosa",
            style: TextStyle(color: BColors.textPrimary(context)),
          ),
          value: _lactoseFree,
          onChanged: (val) => setState(() => _lactoseFree = val),
          activeColor: BColors.primary(context),
          contentPadding: EdgeInsets.symmetric(horizontal: 4),
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
                      const SizedBox(height: 16),

                      Text(
                        "Datos Básicos",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: BColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BUSCADOR INTELIGENTE / ESCÁNER
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return RawAutocomplete<Map<String, dynamic>>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) async {
                                    if (textEditingValue.text.length < 2) {
                                      return const Iterable<
                                        Map<String, dynamic>
                                      >.empty();
                                    }
                                    return await _api.searchMasterProducts(
                                      textEditingValue.text,
                                    );
                                  },
                              displayStringForOption: (option) =>
                                  option['name'] ?? '',
                              onSelected: (Map<String, dynamic> selection) {
                                _fillFormFromMaster(selection);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    // Sincronizar con el controlador de nombre si es "Otros"
                                    // o usar este como el principal.
                                    // Para simplificar, usaremos este como el buscador principal.
                                    return TextField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      style: TextStyle(
                                        color: BColors.textPrimary(context),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: "Buscar o Escanear Producto",
                                        hintText: "Ej: Coca Cola, Arroz...",
                                        labelStyle: TextStyle(
                                          color: BColors.textSecondary(context),
                                        ),
                                        hintStyle: TextStyle(
                                          color: BColors.textSecondary(
                                            context,
                                          ).withOpacity(0.5),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          color: BColors.primary(context),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: _isScanning
                                              ? SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: BColors.primary(
                                                          context,
                                                        ),
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.camera_alt_outlined,
                                                  color: BColors.textPrimary(
                                                    context,
                                                  ),
                                                ),
                                          onPressed: _isScanning
                                              ? null
                                              : () async {
                                                  // Lógica de escaneo con IA
                                                  final scannedName =
                                                      await _scanWithAI();
                                                  if (scannedName != null) {
                                                    textEditingController.text =
                                                        scannedName;
                                                    // Trigger search manually if needed or let user review
                                                  }
                                                },
                                        ),
                                        filled: true,
                                        fillColor: BColors.surfaceVariant(
                                          context,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    );
                                  },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    color: BColors.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 250,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(
                                            index,
                                          );
                                          return ListTile(
                                            leading: option['image_url'] != null
                                                ? Image.network(
                                                    option['image_url'],
                                                    width: 30,
                                                    height: 30,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.inventory_2_outlined,
                                                  ),
                                            title: Text(
                                              option['name'],
                                              style: TextStyle(
                                                color: BColors.textPrimary(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "${option['category'] ?? ''} - ${option['subcategory'] ?? ''}",
                                              style: TextStyle(
                                                color: BColors.textSecondary(
                                                  context,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // --- SECCIONES CONDICIONALES ---
                      if (_selectedMasterId == null) ...[
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
                        const SizedBox(height: 24),

                        // Lógica de Nombre Automático vs Manual
                        if (_selectedCategory?.name == 'Otros') ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            label: "Nombre del Producto",
                            validator: (v) =>
                                v!.isEmpty ? "Campo obligatorio" : null,
                          ),
                          const SizedBox(height: 24),
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
                      ] else ...[
                        // MODO EDICIÓN RÁPIDA (Master seleccionado)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: BColors.primary(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: BColors.primary(context).withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: BColors.primary(context),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Producto Base Seleccionado",
                                    style: TextStyle(
                                      color: BColors.primary(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _computedName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.white12),
                              const SizedBox(height: 8),
                              Text(
                                "Categoría: ${_selectedCategory?.name ?? '...'}",
                                style: TextStyle(color: Colors.white70),
                              ),
                              if (_brandCtrl.text.isNotEmpty)
                                Text(
                                  "Marca: ${_brandCtrl.text}",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              if (_selectedSubCategory != null)
                                Text(
                                  "Tipo: ${_selectedSubCategory?.name}",
                                  style: TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                      ],

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

  bool _shouldShowFlavor() {
    if (_selectedCategory?.name == 'Bebidas') {
      // Mostrar para Jugos, Rehidratantes, Licores, Yogurt, Gaseosa
      final sub = _selectedSubCategory?.name ?? "";
      if (sub == 'Agua' || sub == 'Cerveza') return false;
      return true;
    }
    if (_selectedCategory?.name == 'Abarrotes') {
      final sub = _selectedSubCategory?.name ?? "";
      if (sub.contains('Yogurt') ||
          sub.contains('Golosina') ||
          sub.contains('Snack'))
        return true;
    }
    return false;
  }

  bool _shouldShowSugarFree() {
    final sub = _selectedSubCategory?.name ?? "";
    return sub == 'Gaseosa' || sub == 'Energizante' || sub.contains('Jugo');
  }

  bool _shouldShowLactoseFree() {
    final sub = _selectedSubCategory?.name ?? "";
    return sub.contains('Leche') || sub.contains('Yogurt');
  }
}

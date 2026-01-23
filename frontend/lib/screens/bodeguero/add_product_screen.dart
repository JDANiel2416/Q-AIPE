// lib/screens/add_product_screen.dart
import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import 'package:flutter/services.dart';

// =============================================================================
// PALETA DE COLORES - TEMA CLARO MODERNO
// =============================================================================
class AppColors {
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color primary = Color(0xFF0062FF);
  static const Color primaryLight = Color(0xFFE6F0FF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _isLoading = false;

  // Controladores básicos
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();

  // Estado para campos dinámicos
  String _selectedCategory = 'Bebidas';
  String? _selectedSubCategory; // Nuevo: Tipo de producto específico
  String _selectedUnit = 'ml'; // Nuevo: Unidad de medida
  
  // Controladores para atributos específicos
  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController(); // Unificado: Capacidad/Peso/Cantidad
  bool _hasGas = false;

  final List<String> _categories = ['Bebidas', 'Abarrotes', 'Limpieza', 'Otros'];
  
  // Mapas de configuración
  final Map<String, List<String>> _subCategories = {
    'Bebidas': ['Agua', 'Gaseosa', 'Cerveza', 'Jugo', 'Energizante', 'Rehidratante', 'Licor', 'Otros'],
    'Limpieza': ['Detergente', 'Jabón', 'Suavizante', 'Lavavajillas', 'Lejía', 'Desinfectante', 'Ambientador', 'Otros'],
    'Abarrotes': ['Arroz', 'Azúcar', 'Aceite', 'Fideos', 'Menestras', 'Conservas', 'Lácteos', 'Otros'],
  };

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
    'Agua': ['Cielo', 'San Luis', 'San Mateo', 'Loa', 'Vida', 'Socosani', 'Otras'],
    // Gaseosa
    'Gaseosa': ['Inca Kola', 'Coca-Cola', 'Sprite', 'Fanta', 'Pepsi', 'Seven Up', 'Kola Real', 'Big Cola', 'Otras'],
    // Cerveza
    'Cerveza': ['Pilsen Callao', 'Pilsen Trujillo', 'Cusqueña', 'Cristal', 'Arequipeña', 'Corona', 'Heineken', 'Otras'],
    // Limpieza
    'Detergente': ['Bolívar', 'Ariel', 'Opal', 'Ace', 'Marsella', 'Otras'],
    'Jabón': ['Bolívar', 'Marsella', 'Protex', 'Lux', 'Camay', 'Otras'],
    'Lejía': ['Clorox', 'Sapolio', 'Otras'],
    // Abarrotes comunes
    'Arroz': ['Costeño', 'Paisana', 'Faraón', 'Valle Norte', 'Otras'],
    'Aceite': ['Primor', 'Cocinero', 'Cil', 'Sao', 'Otras'],
    'Leche': ['Gloria', 'Laive', 'Ideal', 'Pura Vida', 'Otras'], // Si hubiera subcategoría Leche
    'Fideos': ['Don Vittorio', 'Molitalia', 'Anita', 'Lavaggi', 'Otras'],
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    _updateDefaults();
  }

  void _updateDefaults() {
    // Resetear subcategoría y unidad por defecto al cambiar categoría
    setState(() {
      _selectedSubCategory = _subCategories[_selectedCategory]?.first;
      _selectedUnit = _unitsByCategory[_selectedCategory]?.first ?? 'unidades';
      
      // Resetear marca
      _selectedBrandPredefined = null;
      _brandCtrl.clear();
      
      // Lógica por defecto para gas
      if (_selectedCategory == 'Bebidas') {
        _updateGasLogic();
      }
    });
  }

  void _updateGasLogic() {
    if (_selectedCategory != 'Bebidas') return;
    
    // Lógica automática para gas
    switch (_selectedSubCategory) {
      case 'Gaseosa':
      case 'Cerveza':
      case 'Energizante': // La mayoría tienen gas
        _hasGas = true;
        break;
      case 'Agua':
        _hasGas = false; // El usuario lo puede cambiar manualmente
        break;
      default:
        _hasGas = false;
    }
  }

  // Getter para nombre computado
  String get _computedName {
    if (_selectedCategory == 'Otros') return _nameCtrl.text;
    String sub = _selectedSubCategory ?? '';
    
    // Usar marca predefinida si existe y no es "Otras", sino usar el campo manual
    String brand = _brandCtrl.text;
    if (_selectedBrandPredefined != null && _selectedBrandPredefined != 'Otras') {
      brand = _selectedBrandPredefined!;
    }

    String content = _contentCtrl.text;
    String unit = _selectedUnit;
    
    // Si estamos en modo manual ("Otras" o sin lista), validamos que haya escrito algo
    if ((_selectedBrandPredefined == null || _selectedBrandPredefined == 'Otras') && brand.isEmpty) {
       return "Complete la marca...";
    }
    
    if (content.isEmpty) return "$sub $brand";
    
    return "$sub $brand $content $unit";
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
      if (_selectedSubCategory == 'Agua' || _selectedSubCategory == 'Gaseosa' || _selectedSubCategory == 'Energizante') {
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

    } else if (_selectedCategory == 'Limpieza' || _selectedCategory == 'Abarrotes') {
      dynamicAttributes["contenido_neto"] = "${_contentCtrl.text} $_selectedUnit";
    } else {
      dynamicAttributes["detalle"] = _contentCtrl.text.isNotEmpty ? "${_contentCtrl.text} $_selectedUnit" : "N/A";
    }

    final newProduct = ProductCreateRequest(
      name: _computedName, // <--- CAMBIO AQUÍ: Usamos el nombre autogenerado
      category: _selectedCategory,
      price: double.parse(_priceCtrl.text),
      stock: int.parse(_stockCtrl.text),
      attributes: dynamicAttributes,
    );

    final result = await _api.addProduct(userId, newProduct);
    
    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto agregado correctamente 📦'),
            backgroundColor: AppColors.primary,
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
              title: const Text("Producto Existente", style: TextStyle(color: Colors.white)),
              content: Text(
                result['message'] ?? "Este producto ya está en tu lista.",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Cerrar primer diálogo
                    _showUpdateConfirmation(); // Mostrar confirmación
                  },
                  child: const Text("Modificar Producto", style: TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.bold)),
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
        title: const Text("Confirmar Actualización", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Deseas actualizar el producto existente con estos nuevos datos?",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              "Precio: S/ ${_priceCtrl.text}",
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            Text(
              "Stock: ${_stockCtrl.text}",
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cerrar diálogo de confirmación
              await _performUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold)),
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
      _selectedCategory,
      double.parse(_priceCtrl.text),
      int.parse(_stockCtrl.text),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto actualizado correctamente ✅'),
            backgroundColor: AppColors.primary,
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
    if (_subCategories.containsKey(_selectedCategory)) {
        fields.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButtonFormField<String>(
                value: _selectedSubCategory,
                items: _subCategories[_selectedCategory]!.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(color: AppColors.textPrimary)),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSubCategory = val!;
                    // Resetear marca al cambiar subtipo para evitar crash
                    _selectedBrandPredefined = null;
                    _brandCtrl.clear();
                    _updateGasLogic();
                  });
                },
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  labelText: "Tipo de ${_selectedCategory.substring(0, _selectedCategory.length - 1)}",
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                iconEnabledColor: AppColors.primary,
                menuMaxHeight: 300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        );
    }

    // LOGICA MARCAS: Dropdown vs Texto Manual
    bool hasPredefinedBrands = _selectedSubCategory != null && _brandsBySubCategory.containsKey(_selectedSubCategory);

    if (hasPredefinedBrands) {
       // Dropdown de Marcas
       fields.add(
         Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButtonFormField<String>(
                value: _selectedBrandPredefined,
                items: _brandsBySubCategory[_selectedSubCategory]!.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b, style: const TextStyle(color: AppColors.textPrimary)),
                )).toList(),
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
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  labelText: "Seleccionar Marca",
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                iconEnabledColor: AppColors.primary,
                menuMaxHeight: 300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
         )
       );
    }

    // Campo de Texto Manual (Si no hay lista o seleccionó "Otras")
    if (!hasPredefinedBrands || _selectedBrandPredefined == 'Otras') {
      fields.add(
        _buildTextField(
          controller: _brandCtrl,
          label: hasPredefinedBrands ? 'Especifique la marca' : 'Marca / Fabricante',
          validator: (v) => v!.isEmpty ? "Requerido" : null,
        ),
      );
      fields.add(const SizedBox(height: 12));
    } else {
      // Espacio si solo mostramos dropdown
      fields.add(const SizedBox(height: 12));
    }


    
    // Campo de Cantidad + Unidad
    if (_selectedCategory != 'Otros') {
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
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    items: (_unitsByCategory[_selectedCategory] ?? ['unidades']).map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u, style: const TextStyle(color: AppColors.textPrimary)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedUnit = val!),
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    iconEnabledColor: AppColors.primary,
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        )
      );
    }

    // Checkbox de GAS
    if (_selectedCategory == 'Bebidas' && _selectedSubCategory == 'Agua') {
      fields.add(const SizedBox(height: 12));
      fields.add(
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            title: const Text("¿Con Gas?", style: TextStyle(color: AppColors.textPrimary)),
            value: _hasGas,
            onChanged: (v) => setState(() => _hasGas = v!),
            activeColor: AppColors.primary,
            checkColor: Colors.white,
          ),
        )
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
      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceVariant,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Datos Básicos",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dropdown de categoría
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items: _categories.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(color: AppColors.textPrimary)),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val!;
                                _updateDefaults();
                              });
                            },
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(
                              labelText: "Categoría",
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                            iconEnabledColor: AppColors.primary,
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
                          validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
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
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Detalles de $_selectedCategory",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: AppColors.border, width: 0.5),
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
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                          child: _isLoading 
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Guardar Producto",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                color: AppColors.primaryLight.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            "Nuevo Producto",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}


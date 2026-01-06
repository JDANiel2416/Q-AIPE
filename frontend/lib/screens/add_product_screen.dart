// lib/screens/add_product_screen.dart
import 'package:flutter/material.dart';
import '../models/inventory_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

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
  
  // Controladores para atributos específicos
  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _capacityCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  bool _hasGas = false;

  final List<String> _categories = ['Bebidas', 'Abarrotes', 'Limpieza', 'Otros'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    Map<String, dynamic> dynamicAttributes = {};
    
    if (_selectedCategory == 'Bebidas') {
      dynamicAttributes = {
        "marca": _brandCtrl.text,
        "capacidad": _capacityCtrl.text,
        "gas": _hasGas
      };
    } else if (_selectedCategory == 'Abarrotes') {
      dynamicAttributes = {
        "marca": _brandCtrl.text,
        "peso": _weightCtrl.text,
      };
    } else {
      dynamicAttributes = {
        "marca": _brandCtrl.text,
        "detalle": "Generado manualmente"
      };
    }

    final newProduct = ProductCreateRequest(
      name: _nameCtrl.text,
      category: _selectedCategory,
      price: double.parse(_priceCtrl.text),
      stock: int.parse(_stockCtrl.text),
      attributes: dynamicAttributes,
    );

    final success = await _api.addProduct(userId, newProduct);

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto agregado correctamente 📦'),
            backgroundColor: Color(0xFF00D9FF),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar producto'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildDynamicFields() {
    switch (_selectedCategory) {
      case 'Bebidas':
        return Column(
          children: [
            _buildTextField(
              controller: _brandCtrl,
              label: 'Marca (Ej: San Luis)',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _capacityCtrl,
              label: 'Capacidad (Ej: 625ml)',
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: CheckboxListTile(
                title: const Text("¿Con Gas?", style: TextStyle(color: Colors.white)),
                value: _hasGas,
                onChanged: (v) => setState(() => _hasGas = v!),
                activeColor: const Color(0xFF00D9FF),
                checkColor: Colors.white,
              ),
            ),
          ],
        );

      case 'Abarrotes':
        return Column(
          children: [
            _buildTextField(
              controller: _brandCtrl,
              label: 'Marca (Ej: Costeño)',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _weightCtrl,
              label: 'Peso Neto (Ej: 1kg)',
            ),
          ],
        );

      default:
        return _buildTextField(
          controller: _brandCtrl,
          label: 'Marca o Fabricante',
        );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        cursorColor: const Color(0xFF00D9FF),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFA0A8B8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          const MinimalistBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Datos Básicos",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Dropdown de categoría
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F2E).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              items: _categories.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(color: Colors.white)),
                              )).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val!;
                                });
                              },
                              dropdownColor: const Color(0xFF1A1F2E),
                              decoration: const InputDecoration(
                                labelText: "Categoría",
                                labelStyle: TextStyle(color: Color(0xFFA0A8B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: const Color(0xFF00D9FF),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          _buildTextField(
                            controller: _nameCtrl,
                            label: "Nombre del Producto",
                            validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
                          ),
                          const SizedBox(height: 12),
                          
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
                          const SizedBox(height: 24),
                          
                          // Sección de detalles específicos
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D9FF),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Detalles de $_selectedCategory",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D9FF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9FF).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.2)),
                            ),
                            child: _buildDynamicFields(),
                          ),

                          const SizedBox(height: 32),
                          
                          // Botón de guardar
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D9FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
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
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
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
            "Nuevo Producto",
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
}

// --- FONDO MINIMALISTA ESTÁTICO ---
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
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
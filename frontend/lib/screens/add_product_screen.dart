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
  
  // Controladores para atributos específicos (Los reusamos según el caso)
  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _capacityCtrl = TextEditingController(); // Para ml/L
  final TextEditingController _weightCtrl = TextEditingController();   // Para kg/g
  bool _hasGas = false; // Solo para bebidas

  final List<String> _categories = ['Bebidas', 'Abarrotes', 'Limpieza', 'Otros'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    // 1. Construir el JSON de atributos dinámicamente
    Map<String, dynamic> dynamicAttributes = {};
    
    // Aquí aplicamos la lógica "Polimórfica" manual
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
      // Genérico
      dynamicAttributes = {
        "marca": _brandCtrl.text,
        "detalle": "Generado manualmente"
      };
    }

    // 2. Crear el objeto
    final newProduct = ProductCreateRequest(
      name: _nameCtrl.text,
      category: _selectedCategory,
      price: double.parse(_priceCtrl.text),
      stock: int.parse(_stockCtrl.text),
      attributes: dynamicAttributes,
    );

    // 3. Enviar al Backend
    final success = await _api.addProduct(userId, newProduct);

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado correctamente 📦')),
        );
        Navigator.pop(context, true); // Retorna 'true' para indicar que recargue la lista
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar producto')),
        );
      }
    }
  }

  // Widget para construir los campos específicos según categoría
  Widget _buildDynamicFields() {
    switch (_selectedCategory) {
      case 'Bebidas':
        return Column(
          children: [
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Marca (Ej: San Luis)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityCtrl,
                    decoration: const InputDecoration(labelText: 'Capacidad (Ej: 625ml)'),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text("¿Con Gas?"),
                    value: _hasGas,
                    onChanged: (v) => setState(() => _hasGas = v!),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'Abarrotes':
        return Column(
          children: [
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Marca (Ej: Costeño)'),
            ),
            TextFormField(
              controller: _weightCtrl,
              decoration: const InputDecoration(labelText: 'Peso Neto (Ej: 1kg)'),
            ),
          ],
        );

      default:
        return TextFormField(
          controller: _brandCtrl,
          decoration: const InputDecoration(labelText: 'Marca o Fabricante'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Producto")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DATOS GENERALES ---
              const Text("Datos Básicos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                    // Limpiar controladores opcionales si quieres
                  });
                },
                decoration: const InputDecoration(labelText: "Categoría"),
              ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nombre del Producto"),
                validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: "Precio (S/)"),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      decoration: const InputDecoration(labelText: "Stock Inicial"),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // --- DATOS ESPECÍFICOS (JSONB) ---
              Text("Detalles de $_selectedCategory", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200)
                ),
                child: _buildDynamicFields(),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Guardar Producto", style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  
  late TextEditingController _priceCtrl;
  late TextEditingController _stockToAddCtrl;
  
  bool _isLoading = false;
  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    // Convert stock to int (handle both int and double from JSON)
    final stockValue = widget.product['stock'];
    _currentStock = (stockValue is int) ? stockValue : (stockValue as num).toInt();
    _priceCtrl = TextEditingController(text: widget.product['price'].toString());
    _stockToAddCtrl = TextEditingController(text: "0");
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _stockToAddCtrl.dispose();
    super.dispose();
  }

  int get _newStock {
    final toAdd = int.tryParse(_stockToAddCtrl.text) ?? 0;
    return _currentStock + toAdd;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = await SessionService().getUserId();
    if (userId == null) return;

    final stockToAdd = int.tryParse(_stockToAddCtrl.text) ?? 0;
    final newPrice = double.tryParse(_priceCtrl.text) ?? 0.0;
    
    // Convert product_id to int to avoid type mismatch
    final productId = (widget.product['product_id'] is int) 
        ? widget.product['product_id'] as int
        : (widget.product['product_id'] as num).toInt();

    final result = await _api.updateProductStock(
      userId,
      productId,
      newPrice,
      stockToAdd,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto actualizado correctamente ✅'),
            backgroundColor: Color(0xFF00D9FF),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes
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
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Info Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00D9FF).withOpacity(0.1),
                                  const Color(0xFF1A1F2E).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00D9FF).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2,
                                        color: Color(0xFF00D9FF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.product['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.product['category'] ?? 'Sin categoría',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoItem(
                                        "Stock Actual",
                                        "$_currentStock unidades",
                                        Icons.inventory,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        "Precio Actual",
                                        "S/ ${widget.product['price'].toStringAsFixed(2)}",
                                        Icons.attach_money,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Edit Section Header
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
                              const Text(
                                "Editar Producto",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D9FF),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Price Field
                          _buildTextField(
                            controller: _priceCtrl,
                            label: "Nuevo Precio (S/)",
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Campo requerido";
                              if (double.tryParse(v) == null) return "Precio inválido";
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Stock Addition Field
                          _buildTextField(
                            controller: _stockToAddCtrl,
                            label: "¿Cuántos productos desea agregar?",
                            icon: Icons.add_box,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Campo requerido";
                              final val = int.tryParse(v);
                              if (val == null) return "Cantidad inválida";
                              if (val < 0) return "No puede ser negativo";
                              return null;
                            },
                            onChanged: (v) => setState(() {}), // Update preview
                          ),

                          const SizedBox(height: 16),

                          // Stock Preview
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Nuevo Stock Total:",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "$_newStock unidades",
                                  style: const TextStyle(
                                    color: Color(0xFF00D9FF),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveChanges,
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
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Guardar Cambios",
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
        ],
      ),
    );
  }

  Widget _buildAppBar() {
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
            "Editar Producto",
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF00D9FF), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: const Color(0xFF00D9FF),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFA0A8B8)),
          prefixIcon: Icon(icon, color: const Color(0xFF00D9FF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// Background Widget
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

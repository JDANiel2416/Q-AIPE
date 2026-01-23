import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import 'package:flutter/services.dart';

import 'bodeguero_colors.dart';

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
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
          SnackBar(
            content: Text('Producto actualizado correctamente ✅'),
            backgroundColor: BColors.primary(context),
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: Text("Eliminar Producto", style: TextStyle(color: Colors.white)),
        content: Text(
          "¿Estás seguro de eliminar '${widget.product['name']}'? Esta acción eliminará el producto permanentemente y no se puede deshacer.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cerrar dialog
              await _deleteProduct();
            },
            child: Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct() async {
    setState(() => _isLoading = true);
    
    final userId = await SessionService().getUserId();
    if (userId == null) return;

    // Convert product_id to int
    final productId = (widget.product['product_id'] is int) 
        ? widget.product['product_id'] as int
        : (widget.product['product_id'] as num).toInt();

    final success = await _api.deleteProduct(userId, productId);
    
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Producto eliminado permanentemente"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true); // Return true so list reloads
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo eliminar el producto"), backgroundColor: BColors.error)
        );
      }
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                          border: Border.all(color: BColors.border(context), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: BColors.primary(context).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: BColors.primary(context),
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
                                        style: TextStyle(
                                          color: BColors.textPrimary(context),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.product['category'] ?? 'Sin categoría',
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
                            const SizedBox(height: 16),
                            Divider(color: BColors.divider(context)),
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
                              color: BColors.primary(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Editar Producto",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Price Field
                      _buildTextField(
                        controller: _priceCtrl,
                        label: "Nuevo Precio (S/)",
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
                          color: BColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Nuevo Stock Total:",
                              style: TextStyle(
                                color: BColors.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "$_newStock unidades",
                              style: TextStyle(
                                color: BColors.primary(context),
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
                            backgroundColor: BColors.primary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: BColors.primary(context).withOpacity(0.4),
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
                                  "Guardar Cambios",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      
                      // Delete Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _confirmDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, // Ghost button
                            foregroundColor: BColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: BColors.error)
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                                  "Eliminar Producto",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
              child: Icon(Icons.arrow_back_ios_new, color: BColors.primary(context), size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "Editar Producto",
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: BColors.textSecondary(context), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: BColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: BColors.textPrimary(context),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: BColors.textPrimary(context), fontWeight: FontWeight.w600),
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
}

// Background Widget


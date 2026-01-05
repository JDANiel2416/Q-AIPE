import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'add_product_screen.dart'; // <--- IMPORTANTE: Importa la nueva pantalla

class BodegueroScreen extends StatefulWidget {
  const BodegueroScreen({super.key});

  @override
  State<BodegueroScreen> createState() => _BodegueroScreenState();
}

class _BodegueroScreenState extends State<BodegueroScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true); // Muestra carga al refrescar
    final uid = await SessionService().getUserId();
    if (uid != null) {
      _userId = uid;
      final data = await _api.getMyInventory(uid);
      setState(() {
        _products = data;
        _isLoading = false;
      });
    }
  }

  void _toggleProduct(int index, bool value) async {
    // 1. Actualización optimista
    setState(() {
      _products[index]['in_stock'] = value;
    });

    // 2. Llamada al backend
    final success = await _api.toggleStock(_userId, _products[index]['product_id'], value);
    
    // 3. Revertir si falla
    if (!success) {
      setState(() {
        _products[index]['in_stock'] = !value;
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de conexión")));
    }
  }

  // --- NUEVA FUNCIÓN PARA IR A AGREGAR ---
  void _navigateToAddProduct() async {
    // Push devuelve el resultado cuando hacemos Navigator.pop(context, true)
    final bool? result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const AddProductScreen())
    );

    // Si result es true, significa que se agregó algo y debemos recargar
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Bodega 🏪"),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SessionService().logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      // --- BOTÓN FLOTANTE NUEVO ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProduct,
        label: const Text("Agregar Producto"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty 
            ? const Center(child: Text("No tienes productos. ¡Agrega uno!"))
            : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final prod = _products[i];
                return Card(
                  color: Colors.white10, // Ojo: Si usas tema claro, esto puede verse muy tenue
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: SwitchListTile(
                    activeColor: Colors.greenAccent,
                    title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("S/ ${prod['price'].toStringAsFixed(2)} | Stock: ${prod['stock']}"),
                    value: prod['in_stock'],
                    onChanged: (val) => _toggleProduct(i, val),
                    secondary: Icon(
                      prod['in_stock'] ? Icons.check_circle : Icons.remove_circle_outline,
                      color: prod['in_stock'] ? Colors.green : Colors.grey,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
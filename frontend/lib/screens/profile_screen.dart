import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  
  // Controllers
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bodegaNameCtrl;
  late TextEditingController _bodegaAddressCtrl;
  
  String _fullName = "";
  String _email = "";
  String _dni = "";
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _bodegaNameCtrl = TextEditingController();
    _bodegaAddressCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bodegaNameCtrl.dispose();
    _bodegaAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    final userId = await SessionService().getUserId();
    if (userId != null) {
      final profile = await _api.getProfile(userId);
      
      if (mounted) {
        setState(() {
          _fullName = profile['full_name'] ?? "";
          _emailCtrl.text = profile['email'] ?? "";
          _phoneCtrl.text = profile['phone_number'] ?? "";
          _bodegaNameCtrl.text = profile['bodega_name'] ?? "";
          _bodegaAddressCtrl.text = profile['bodega_address'] ?? "";
          _email = profile['email'] ?? "";
          _dni = profile['dni'] ?? "";
          _photoUrl = profile['profile_photo_url'];
          // Don't reset _selectedImage here, keep user selection
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final userId = await SessionService().getUserId();
    if (userId == null) return;
    
    // 1. Update text profile
    final result = await _api.updateProfile(
      userId,
      _emailCtrl.text,
      _phoneCtrl.text,
      _bodegaNameCtrl.text,
    );

    // 2. Upload photo if selected
    if (_selectedImage != null) {
      await _api.uploadProfilePhoto(userId, _selectedImage!);
    }
    
    setState(() => _isSaving = false);
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente ✅'),
            backgroundColor: Color(0xFF00D9FF),
          ),
        );
        Navigator.pop(context, true); // Return to dashboard
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : Stack(
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
                              children: [
                                // Profile Photo Section
                                _buildPhotoSection(),
                                const SizedBox(height: 32),
                                
                                // Personal Info Card
                                _buildSectionHeader("Información Personal", Icons.person),
                                const SizedBox(height: 16),
                                _buildInfoCard([
                                  _buildReadOnlyField("Nombre completo", _fullName.isEmpty ? "Cargando..." : _fullName, Icons.badge),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emailCtrl,
                                    label: "Email",
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _phoneCtrl,
                                    label: "Teléfono",
                                    icon: Icons.phone,
                                    keyboardType: TextInputType.phone,
                                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildReadOnlyField("DNI", _dni, Icons.credit_card),
                                ]),
                                
                                const SizedBox(height: 24),
                                
                                // Bodega Info Card
                                _buildSectionHeader("Información de Bodega", Icons.store),
                                const SizedBox(height: 16),
                                _buildInfoCard([
                                  _buildTextField(
                                    controller: _bodegaNameCtrl,
                                    label: "Nombre de la bodega",
                                    icon: Icons.storefront,
                                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    "Dirección",
                                    _bodegaAddressCtrl.text.isEmpty ? "No disponible" : _bodegaAddressCtrl.text,
                                    Icons.location_on,
                                  ),
                                ]),
                                
                                const SizedBox(height: 32),
                                
                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00D9FF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isSaving
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
            "Mi Perfil",
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

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00D9FF), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF1A1F2E),
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (_photoUrl != null 
                        ? NetworkImage("${ApiService.host}$_photoUrl") 
                        : null) as ImageProvider?,
                child: (_selectedImage == null && _photoUrl == null)
                    ? const Icon(Icons.store, color: Color(0xFF00D9FF), size: 50)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Toca el ícono para cambiar foto",
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
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
        Icon(icon, color: const Color(0xFF00D9FF), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D9FF),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF00D9FF),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFA0A8B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF00D9FF)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? "No disponible" : value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
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
    );
  }
}

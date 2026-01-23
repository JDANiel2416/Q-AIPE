import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  
  const ProfileScreen({Key? key, this.isEmbedded = false}) : super(key: key);

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
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
        // Only pop when not embedded (has its own route)
        if (!widget.isEmbedded) {
          Navigator.pop(context, true);
        }
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
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 10,
                        bottom: widget.isEmbedded ? 120 : 10,
                      ),
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
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                      shadowColor: AppColors.primary.withOpacity(0.4),
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
                                              color: Colors.white,
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
          // Back button - only show when NOT embedded
          if (!widget.isEmbedded) ...[
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
          ],
          const Text(
            "Mi Perfil",
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

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: AppColors.surfaceVariant,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_photoUrl != null
                          ? NetworkImage("${ApiService.host}$_photoUrl")
                          : null) as ImageProvider?,
                  child: (_selectedImage == null && _photoUrl == null)
                      ? const Icon(Icons.person_outline, color: AppColors.textMuted, size: 60)
                      : null,
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Toca para actualizar tu foto",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
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

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface, // Clean white
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? "No disponible" : value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.border),
        ],
      ),
    );
  }
}

// Background Widget


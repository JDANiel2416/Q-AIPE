import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../common/login_screen.dart';
import '../../services/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import 'bodeguero_colors.dart';

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

  // Delivery settings
  bool _hasDelivery = false;
  double _deliveryFee = 3.00;
  double _deliveryRadius = 2.0;
  String? _bodegaId;

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
          _bodegaId = profile['bodega_id'];
          // Don't reset _selectedImage here, keep user selection
          _isLoading = false;
        });

        // Load delivery settings if we have bodega_id
        if (_bodegaId != null) {
          _loadDeliverySettings();
        }
      }
    }
  }

  Future<void> _loadDeliverySettings() async {
    if (_bodegaId == null) return;
    try {
      final settings = await _api.getDeliverySettings(_bodegaId!);
      if (mounted) {
        setState(() {
          _hasDelivery = settings['has_delivery'] ?? false;
          _deliveryFee = (settings['delivery_fee'] ?? 3.00).toDouble();
          _deliveryRadius = (settings['delivery_radius_km'] ?? 2.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading delivery settings: $e');
    }
  }

  Future<void> _saveDeliverySettings() async {
    if (_bodegaId == null) return;
    try {
      await _api.updateDeliverySettings(
        _bodegaId!,
        _hasDelivery,
        _deliveryFee,
        _deliveryRadius,
      );
    } catch (e) {
      print('Error saving delivery settings: $e');
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

  Future<void> _logout() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BColors.surface(context),
        title: Text(
          "Cerrar Sesión",
          style: TextStyle(color: BColors.textPrimary(context)),
        ),
        content: Text(
          "¿Estás seguro de que deseas salir?",
          style: TextStyle(color: BColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancelar",
              style: TextStyle(color: BColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Salir",
              style: TextStyle(
                color: BColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(
      () => _isSaving = true,
    ); // Reusamos el estado de carga para bloquear UI

    await SessionService().logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: BColors.primary(context)),
            )
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
                            _buildSectionHeader(
                              "Información Personal",
                              Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard([
                              _buildReadOnlyField(
                                "Nombre completo",
                                _fullName.isEmpty ? "Cargando..." : _fullName,
                                Icons.badge,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _emailCtrl,
                                label: "Email",
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    v!.isEmpty ? "Campo requerido" : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _phoneCtrl,
                                label: "Teléfono",
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    v!.isEmpty ? "Campo requerido" : null,
                              ),
                              const SizedBox(height: 16),
                              _buildReadOnlyField(
                                "DNI",
                                _dni,
                                Icons.credit_card,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // Bodega Info Card
                            _buildSectionHeader(
                              "Información de Bodega",
                              Icons.store,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard([
                              _buildTextField(
                                controller: _bodegaNameCtrl,
                                label: "Nombre de la bodega",
                                icon: Icons.storefront,
                                validator: (v) =>
                                    v!.isEmpty ? "Campo requerido" : null,
                              ),
                              const SizedBox(height: 16),
                              _buildReadOnlyField(
                                "Dirección",
                                _bodegaAddressCtrl.text.isEmpty
                                    ? "No disponible"
                                    : _bodegaAddressCtrl.text,
                                Icons.location_on,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // Delivery Section
                            _buildSectionHeader(
                              "Configuración de Delivery",
                              Icons.delivery_dining,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard([
                              _buildDeliveryToggle(),
                              if (_hasDelivery) ...[
                                const SizedBox(height: 16),
                                _buildDeliveryFeeField(),
                                const SizedBox(height: 16),
                                _buildDeliveryRadiusField(),
                              ],
                            ]),

                            const SizedBox(height: 24),

                            // Preferences Section
                            _buildSectionHeader("Preferencias", Icons.settings),
                            const SizedBox(height: 16),
                            _buildInfoCard([_buildThemeToggle()]),

                            const SizedBox(height: 32),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
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
                                child: _isSaving
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
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Logout Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _logout,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: BColors.error,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  foregroundColor: BColors.error,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout, color: BColors.error),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Cerrar Sesión",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: BColors.error,
                                      ),
                                    ),
                                  ],
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
          ],
          Text(
            "Mi Perfil",
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
                  border: Border.all(color: BColors.surface(context), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: BColors.shadowMedium(context),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: BColors.surfaceVariant(context),
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_photoUrl != null
                                ? NetworkImage("${ApiService.host}$_photoUrl")
                                : null)
                            as ImageProvider?,
                  child: (_selectedImage == null && _photoUrl == null)
                      ? Icon(
                          Icons.person_outline,
                          color: BColors.textMuted(context),
                          size: 60,
                        )
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
                      color: BColors.primary(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BColors.surface(context),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BColors.shadowLight(context),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Toca para actualizar tu foto",
          style: TextStyle(
            color: BColors.textSecondary(context),
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
            color: BColors.primary(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
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
      style: TextStyle(
        color: BColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      cursorColor: BColors.primary(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: BColors.textSecondary(context)),
        prefixIcon: Icon(icon, color: BColors.textSecondary(context)),
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

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BColors.surface(context), // Clean white
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BColors.textSecondary(context), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: BColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? "No disponible" : value,
                  style: TextStyle(
                    color: BColors.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: BColors.border(context)),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeProvider().themeMode,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1A1A)
                    : BColors.primaryLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: BColors.primary(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Modo Oscuro",
                    style: TextStyle(
                      color: BColors.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? "Activado - AMOLED" : "Desactivado",
                    style: TextStyle(
                      color: BColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isDark,
              onChanged: (value) => ThemeProvider().toggleTheme(),
              activeColor: BColors.primary(context),
              activeTrackColor: BColors.primary(context).withOpacity(0.3),
              inactiveThumbColor: BColors.textMuted(context),
              inactiveTrackColor: BColors.surfaceVariant(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryToggle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hasDelivery
                ? BColors.primary(context).withOpacity(0.15)
                : BColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.delivery_dining,
            color: _hasDelivery
                ? BColors.primary(context)
                : BColors.textMuted(context),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ofrecer Delivery",
                style: TextStyle(
                  color: BColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _hasDelivery ? "Activado" : "Desactivado",
                style: TextStyle(
                  color: BColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _hasDelivery,
          onChanged: (value) {
            setState(() => _hasDelivery = value);
            _saveDeliverySettings();
          },
          activeColor: BColors.primary(context),
          activeTrackColor: BColors.primary(context).withOpacity(0.3),
          inactiveThumbColor: BColors.textMuted(context),
          inactiveTrackColor: BColors.surfaceVariant(context),
        ),
      ],
    );
  }

  Widget _buildDeliveryFeeField() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BColors.primaryLight(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.attach_money,
            color: BColors.primary(context),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tarifa de Delivery",
                style: TextStyle(
                  color: BColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "S/ ${_deliveryFee.toStringAsFixed(2)}",
                style: TextStyle(
                  color: BColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFeeButton(Icons.remove, () {
              if (_deliveryFee > 0.5) {
                setState(() => _deliveryFee -= 0.5);
                _saveDeliverySettings();
              }
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "S/ ${_deliveryFee.toStringAsFixed(1)}",
                style: TextStyle(
                  color: BColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            _buildFeeButton(Icons.add, () {
              if (_deliveryFee < 20) {
                setState(() => _deliveryFee += 0.5);
                _saveDeliverySettings();
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFeeButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: BColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: BColors.textPrimary(context)),
      ),
    );
  }

  Widget _buildDeliveryRadiusField() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BColors.primaryLight(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.radar, color: BColors.primary(context), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Radio de Cobertura",
                style: TextStyle(
                  color: BColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: BColors.primary(context),
                  inactiveTrackColor: BColors.surfaceVariant(context),
                  thumbColor: BColors.primary(context),
                  overlayColor: BColors.primary(context).withOpacity(0.2),
                  valueIndicatorColor: BColors.primary(context),
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                ),
                child: Slider(
                  value: _deliveryRadius,
                  min: 0.5,
                  max: 5.0,
                  divisions: 9,
                  label: "${_deliveryRadius.toStringAsFixed(1)} km",
                  onChanged: (value) {
                    setState(() => _deliveryRadius = value);
                  },
                  onChangeEnd: (value) => _saveDeliverySettings(),
                ),
              ),
              Text(
                "${_deliveryRadius.toStringAsFixed(1)} km de radio",
                style: TextStyle(
                  color: BColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Background Widget

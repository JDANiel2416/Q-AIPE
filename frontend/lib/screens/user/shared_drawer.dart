import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../common/login_screen.dart';
import 'home_screen.dart';
import 'my_chats_screen.dart';
import 'orders_history_screen.dart';
import 'home_colors.dart'; // Importar helper de colores
import '../../services/theme_provider.dart'; // Importar ThemeProvider

/// Widget mixin que agrega funcionalidad de drawer animado a cualquier página
mixin UserDrawerMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late AnimationController drawerController;
  bool isDrawerOpen = false;
  double drawerDragStart = 0;
  String userFirstName = "Usuario";

  void initDrawer() {
    drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadUserName();
  }

  void disposeDrawer() {
    drawerController.dispose();
  }

  Future<void> _loadUserName() async {
    final userId = await SessionService().getUserId();
    if (userId != null) {
      final profile = await ApiService().getUserProfile(userId);
      if (mounted && profile.isNotEmpty) {
        setState(() {
          userFirstName = profile['first_name'] ?? "Usuario";
        });
      }
    }
  }

  void openDrawer() {
    drawerController.animateTo(1.0, curve: Curves.easeOutCubic);
    isDrawerOpen = true;
  }

  void closeDrawer() {
    drawerController.animateTo(0.0, curve: Curves.easeOutCubic);
    isDrawerOpen = false;
  }

  /// Manejador de inicio de swipe
  void onHorizontalDragStart(DragStartDetails details, double drawerWidth) {
    drawerDragStart = details.globalPosition.dx;
  }

  /// Manejador de actualización de swipe
  void onHorizontalDragUpdate(DragUpdateDetails details, double drawerWidth) {
    final delta = details.globalPosition.dx - drawerDragStart;

    if (isDrawerOpen) {
      final newValue = 1.0 + (delta / drawerWidth);
      drawerController.value = newValue.clamp(0.0, 1.0);
    } else {
      final newValue = delta / drawerWidth;
      drawerController.value = newValue.clamp(0.0, 1.0);
    }
  }

  /// Manejador de fin de swipe
  void onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (velocity > 500) {
      openDrawer();
    } else if (velocity < -500) {
      closeDrawer();
    } else {
      if (drawerController.value > 0.5) {
        openDrawer();
      } else {
        closeDrawer();
      }
    }
  }

  Widget buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HomeColors.primaryLight(context).withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: HomeColors.primary(context), size: 20),
      ),
    );
  }

  Widget buildDrawerOverlay(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.80;

    return AnimatedBuilder(
      animation: drawerController,
      builder: (context, child) {
        if (drawerController.value == 0) return const SizedBox.shrink();

        return Stack(
          children: [
            // Fondo oscuro que se desvanece
            GestureDetector(
              onTap: closeDrawer,
              child: Container(
                color: Colors.black.withOpacity(0.5 * drawerController.value),
              ),
            ),
            // El drawer que se desliza
            Transform.translate(
              offset: Offset(
                -drawerWidth + (drawerWidth * drawerController.value),
                0,
              ),
              child: _buildModernDrawer(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernDrawer(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.80,
      height: double.infinity,
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowMedium(context),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER DEL PERFIL
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HomeColors.primaryLight(context).withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomeColors.primary(context),
                      boxShadow: [
                        BoxShadow(
                          color: HomeColors.primary(context).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: HomeColors.surface(context),
                      child: Icon(
                        Icons.person,
                        color: HomeColors.primary(context),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userFirstName,
                    style: TextStyle(
                      color: HomeColors.textPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: HomeColors.primary(context),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Verificado RENIEC",
                        style: TextStyle(
                          color: HomeColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // OPCIONES DEL MENÚ
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildDrawerItem(context, Icons.home_rounded, "Inicio", () {
                    closeDrawer();
                    // Si ya estamos en HomeScreen (lo sabemos si T es HomeScreen), no navegar
                    if (widget is! HomeScreen) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    }
                  }),
                  _buildDrawerItem(
                    context,
                    Icons.history_rounded,
                    "Historial de Pedidos",
                    () {
                      closeDrawer();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrdersHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.chat_bubble_outline_rounded,
                    "Mis Chats",
                    () {
                      closeDrawer();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyChatsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.favorite_outline_rounded,
                    "Favoritos",
                    () {},
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.place_outlined,
                    "Mis Direcciones",
                    () {},
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: HomeColors.divider(context),
                      height: 30,
                    ),
                  ),
                  // Switch de Modo Oscuro
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeProvider().themeMode,
                    builder: (context, mode, child) {
                      final isDark = mode == ThemeMode.dark;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: HomeColors.primaryLight(
                                context,
                              ).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: HomeColors.primary(context),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            "Modo Oscuro",
                            style: TextStyle(
                              color: HomeColors.textPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (val) => ThemeProvider().toggleTheme(),
                            activeColor: HomeColors.primary(context),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.settings_outlined,
                    "Configuración",
                    () {},
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.help_outline_rounded,
                    "Ayuda y Soporte",
                    () {},
                  ),
                ],
              ),
            ),

            // BOTÓN CERRAR SESIÓN
            Padding(
              padding: const EdgeInsets.all(24),
              child: InkWell(
                onTap: () async {
                  await SessionService().logout();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: HomeColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HomeColors.error.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: HomeColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Cerrar Sesión",
                        style: TextStyle(
                          color: HomeColors.error,
                          fontWeight: FontWeight.w600,
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

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HomeColors.primaryLight(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: HomeColors.primary(context), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: HomeColors.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: HomeColors.primaryLight(context).withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}

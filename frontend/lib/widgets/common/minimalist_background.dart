import 'package:flutter/material.dart';
import '../../screens/user/home_colors.dart';

// --- FONDO MINIMALISTA DINÁMICO (LIGHT/DARK) ---
class MinimalistBackground extends StatelessWidget {
  const MinimalistBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = HomeColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  HomeColors.minimalistBackground(context), // Negro AMOLED
                  HomeColors.accentBackground(
                    context,
                  ), // Negro ligeramente más claro
                  HomeColors.minimalistBackground(context), // Negro AMOLED
                ]
              : [
                  const Color(0xFFF9FAFB), // Gris muy claro
                  const Color(0xFFFFFFFF), // Blanco
                  const Color(0xFFF3F4F6), // Gris suave
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Acento sutil en la esquina superior
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          HomeColors.primary(
                            context,
                          ).withOpacity(0.08), // Azul sutil para dark
                          Colors.transparent,
                        ]
                      : [
                          const Color(
                            0xFF10B981,
                          ).withOpacity(0.08), // Verde suave para light
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          // Acento sutil en la esquina inferior
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          HomeColors.primary(
                            context,
                          ).withOpacity(0.05), // Azul más sutil
                          Colors.transparent,
                        ]
                      : [
                          const Color(
                            0xFF10B981,
                          ).withOpacity(0.05), // Verde más sutil
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

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../home_colors.dart';

class HomeInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool isLoading;
  final bool isTyping;
  final VoidCallback onSubmitted;

  const HomeInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.isLoading,
    required this.isTyping,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: HomeColors.surface(
              context,
            ).withOpacity(0.7), // Semi-transparente
            borderRadius: BorderRadius.circular(26),
            // Sombra suave para delimitar
            boxShadow: [
              BoxShadow(
                color: HomeColors.shadowMedium(context).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
            // Borde sutil opcional para reforzar el efecto vidrio
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: false, // Solo se muestra cuando hay scroll
                  radius: const Radius.circular(8),
                  thickness: 4,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    scrollController: scrollController,
                    enabled: !isLoading,
                    maxLines: 5, // Máximo 5 líneas visibles
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: isLoading
                          ? HomeColors.textMuted(context)
                          : HomeColors.textPrimary(context),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    cursorColor: HomeColors.primary(context),
                    decoration: InputDecoration(
                      hintText: isLoading
                          ? "Buscando..."
                          : "Escribe tu pedido...",
                      hintStyle: TextStyle(
                        color: HomeColors.textMuted(context).withOpacity(0.5),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 14,
                      ),
                      isDense: true,
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                    onSubmitted: null, // Enter hace salto de línea
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botón de envío
              Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6, top: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: (isTyping || isLoading)
                        ? HomeColors.primary(context)
                        : HomeColors.surfaceVariant(context),
                    shape: BoxShape.circle,
                    boxShadow: (isTyping || isLoading)
                        ? [
                            BoxShadow(
                              color: HomeColors.primary(
                                context,
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: IconButton(
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: isTyping
                                ? Colors.white
                                : HomeColors.textMuted(context),
                            size: 20,
                          ),
                    onPressed: isLoading ? null : onSubmitted,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

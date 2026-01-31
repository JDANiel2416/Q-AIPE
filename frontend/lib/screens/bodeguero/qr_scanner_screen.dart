import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import 'bodeguero_colors.dart';

class QRScannerScreen extends StatefulWidget {
  final String bodegaId;

  const QRScannerScreen({Key? key, required this.bodegaId}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ApiService _api = ApiService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    print("DEBUG QR: _onDetect called, _isProcessing=$_isProcessing");
    if (_isProcessing) {
      print("DEBUG QR: Skipped - already processing");
      return;
    }
    final List<Barcode> barcodes = capture.barcodes;
    print("DEBUG QR: Found ${barcodes.length} barcodes");

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final code = barcode.rawValue!;
        print(
          "DEBUG QR: Raw value = ${code.substring(0, code.length > 50 ? 50 : code.length)}...",
        );

        // 1. Intentar decodificar como lista JSON (QR Unificado)
        try {
          final decoded = jsonDecode(code);
          if (decoded is List) {
            print(
              "DEBUG QR: Detected unified QR with ${decoded.length} tokens",
            );
            _processUnifiedQR(decoded.cast<String>());
            return;
          }
        } catch (_) {
          // No es JSON, continuamos
        }

        // 2. Validar formato legacy (RES|...)
        if (code.startsWith("RES|")) {
          print("DEBUG QR: Detected legacy RES| format");
          _processQRCode(code);
          break;
        }
      }
    }
  }

  Future<void> _processUnifiedQR(List<String> tokens) async {
    setState(() => _isProcessing = true);

    try {
      bool found = false;
      String? lastError;

      // Probar cada token hasta encontrar el válido para ESTA bodega
      for (var token in tokens) {
        try {
          final result = await _api.validateReservation(token, widget.bodegaId);
          if (result['success'] == true) {
            found = true;

            if (!mounted) return;
            // Éxito encontrado
            if (result['already_validated'] == true) {
              _showResultDialog(
                success: true,
                title: "Ticket Ya Usado",
                message: result['message'],
                data: result['reservation'],
                isWarning: true,
              );
            } else {
              _showPaymentOptionsDialog(result['reservation']);
            }
            break; // Salir del loop si encontramos el nuestro
          }
        } catch (e) {
          // Este token no era nuestro o error de red, seguimos buscando
          lastError = e.toString();
        }
      }

      if (!found && mounted) {
        _showResultDialog(
          success: false,
          title: "Ticket No Válido",
          message: "Este QR no contiene pedidos para esta bodega.",
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          success: false,
          title: "Error",
          message: "Error procesando QR unificado: $e",
        );
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() => _isProcessing = true);
    // Pausar cámara o mostrar loading

    try {
      final result = await _api.validateReservation(qrData, widget.bodegaId);

      if (!mounted) return;

      if (result['success'] == true) {
        // Si ya fue validado, mostrar alerta
        if (result['already_validated'] == true) {
          _showResultDialog(
            success: true,
            title: "Ticket Ya Usado",
            message: result['message'],
            data: result['reservation'],
            isWarning: true,
          );
        } else {
          // Si es válido y PENDING, mostrar opciones de pago
          _showPaymentOptionsDialog(result['reservation']);
        }
      } else {
        // Error
        _showResultDialog(
          success: false,
          title: "Error de Validación",
          message: result['message'] ?? "Código inválido",
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          success: false,
          title: "Error",
          message: "Ocurrió un error al validar: $e",
        );
      }
    }
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    bool isWarning = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: BColors.surface(context),
        title: Row(
          children: [
            Icon(
              success
                  ? (isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded)
                  : Icons.error_outline_rounded,
              color: success
                  ? (isWarning ? Colors.orange : BColors.success)
                  : BColors.error,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: BColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: BColors.textSecondary(context),
                fontSize: 16,
              ),
            ),
            if (data != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow(
                "Reserva:",
                "#${data['id'].toString().substring(0, 8)}...",
              ),
              _buildInfoRow("Cliente:", "${data['client']}"),
              _buildInfoRow("Total:", "S/ ${data['total']}"),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              setState(
                () => _isProcessing = false,
              ); // Permitir escanear de nuevo
            },
            child: Text(
              "Escanear Otro",
              style: TextStyle(color: BColors.primary(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Salir de la pantalla de scanner
            },
            style: FilledButton.styleFrom(backgroundColor: BColors.success),
            child: const Text("Finalizar"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: BColors.textMuted(context),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: BColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptionsDialog(Map<String, dynamic> data) {
    final status = data['status'] ?? 'PENDING';
    final isCredit = status == 'CREDIT';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: BColors.surface(context),
        title: Row(
          children: [
            Icon(
              isCredit
                  ? Icons.access_time_filled_rounded
                  : Icons.verified_rounded,
              color: isCredit ? Colors.orange : BColors.primary(context),
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCredit ? "Cobrar Deuda" : "Ticket Válido",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCredit
                  ? "Este ticket tiene un pago pendiente."
                  : "Seleccione la acción para finalizar:",
              style: TextStyle(color: BColors.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BColors.background(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("Cliente:", "${data['client']}"),
                  const SizedBox(height: 4),
                  _buildInfoRow("Total:", "S/ ${data['total']}"),
                  if (isCredit) ...[
                    const SizedBox(height: 4),
                    _buildInfoRow("Estado:", "Fiado / Pendiente"),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón Fiado (Solo si NO es fiado aún)
          if (!isCredit)
            OutlinedButton.icon(
              icon: const Icon(
                Icons.pending_actions_rounded,
                color: Colors.orange,
              ),
              label: const Text(
                "Fiado",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: () => _processStatusUpdate(data['id'], "CREDIT", ctx),
            ),

          // Botón Cancelar (Siempre disponible para escanear otro)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
            },
            child: Text(
              "Cancelar",
              style: TextStyle(color: BColors.textSecondary(context)),
            ),
          ),

          // Botón Pagado
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("Pagado"),
            style: FilledButton.styleFrom(
              backgroundColor: BColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _processStatusUpdate(data['id'], "PAID", ctx),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceEvenly,
      ),
    );
  }

  Future<void> _processStatusUpdate(
    String reservationId,
    String status,
    BuildContext dialogContext,
  ) async {
    Navigator.pop(dialogContext); // Cerrar diálogo de opciones
    setState(() => _isProcessing = true);

    try {
      final result = await _api.updateOrderStatus(reservationId, status);
      if (!mounted) return;

      if (result['success'] == true) {
        _showResultDialog(
          success: true,
          title: status == "PAID" ? "¡Pago Exitoso!" : "Registrado como Fiado",
          message: "El pedido se ha procesado correctamente.",
          data: null,
        );
      } else {
        _showResultDialog(
          success: false,
          title: "Error",
          message: result['message'],
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          success: false,
          title: "Error",
          message: "Falló la actualización: $e",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay Oscuro con ventana transparente
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode
                  .srcOut, // Lo que dibujemos será transparente ("cortado")
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstIn,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Marco visual de la zona de escaneo
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Esquinas
                  _buildCorner(true, true),
                  _buildCorner(true, false),
                  _buildCorner(false, true),
                  _buildCorner(false, false),
                ],
              ),
            ),
          ),
          // Botón Cerrar y Título
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Escanear Ticket",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            switch (state.torchState) {
                              case TorchState.off:
                                return const Icon(
                                  Icons.flash_off,
                                  color: Colors.white,
                                );
                              case TorchState.on:
                                return const Icon(
                                  Icons.flash_on,
                                  color: Colors.yellow,
                                );
                              default:
                                return const Icon(
                                  Icons.flash_off,
                                  color: Colors.grey,
                                );
                            }
                          },
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Text(
                    "Apunta el código QR del cliente",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
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

  Widget _buildCorner(bool top, bool left) {
    return Positioned(
      top: top ? 0 : null,
      bottom: !top ? 0 : null,
      left: left ? 0 : null,
      right: !left ? 0 : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: BColors.success, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: BColors.success, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: BColors.success, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: BColors.success, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

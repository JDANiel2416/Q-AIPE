import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'home_colors.dart'; // Importar helper de colores
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class TicketScreen extends StatelessWidget {
  final Map<String, dynamic> ticketData;

  const TicketScreen({Key? key, required this.ticketData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = ticketData['items'] as List;
    final total = ticketData['total'];
    final qrData = ticketData['qr_data'];
    final userName = ticketData['formatted_name'];
    final isDark = HomeColors.isDark(context);

    return Scaffold(
      backgroundColor: HomeColors.background(context),
      appBar: AppBar(
        title: const Text("Tu Ticket de Reserva"),
        backgroundColor: HomeColors.surface(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
        iconTheme: IconThemeData(
          color: HomeColors.textPrimary(context), // Flecha atrás dinámica
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // TICKET CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HomeColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: HomeColors.shadowLight(context),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: HomeColors.success,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "¡Reserva Confirmada!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Cliente: $userName",
                    style: TextStyle(
                      fontSize: 16,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                  const Divider(height: 40),

                  // Lista de productos
                  // Lista de productos agrupada por bodega
                  ..._buildGroupedItems(context, items),

                  Divider(height: 40, color: HomeColors.divider(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TOTAL",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: HomeColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        "S/${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // QR CODE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors
                          .white, // El QR siempre necesita fondo blanco para leerse
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Muestra este QR en bodega",
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // BOTONES DE ACCIÓN
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _generateAndPrintPdf(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Descargar PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (ticketData['status'] == 'PENDING' && ticketData['id'] != null)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          _cancelOrder(context, ticketData['id'].toString()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Cancelar Pedido"),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: Text(
                  "Volver al Inicio",
                  style: TextStyle(color: HomeColors.primary(context)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: HomeColors.primary(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems(BuildContext context, List<dynamic> items) {
    // 1. Agrupar por nombre de bodega
    final Map<String, List<dynamic>> grouped = {};
    for (var item in items) {
      final key = item['bodega_name'] ?? 'Bodega';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(item);
    }

    // 2. Construir widgets
    List<Widget> widgets = [];
    grouped.forEach((bodegaName, bodegaItems) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.store, size: 16, color: HomeColors.primary(context)),
              const SizedBox(width: 8),
              Text(
                bodegaName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: HomeColors.primary(context),
                ),
              ),
            ],
          ),
        ),
      );

      for (var item in bodegaItems) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4), // Indentado
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${item['quantity']}x ${item['product_name']}",
                  style: TextStyle(
                    color: HomeColors.textPrimary(context),
                    fontSize: 13,
                  ),
                ),
                Text(
                  "S/${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}",
                  style: TextStyle(
                    color: HomeColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8)); // Espacio entre grupos
    });

    return widgets;
  }

  Future<void> _generateAndPrintPdf(BuildContext context) async {
    final pdf = pw.Document();
    final items = ticketData['items'] as List;

    // Define colors matching the modern UI palette
    final primaryBlue = PdfColor.fromHex('#0062ff');
    final darkGray = PdfColor.fromHex('#111827');
    final lightGray = PdfColor.fromHex('#6B7280');
    final successGreen = PdfColor.fromHex('#10B981');

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: primaryBlue,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Comprobante de Reserva",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Chek",
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.white),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Client info
              pw.Text(
                "Cliente: ${ticketData['formatted_name']}",
                style: pw.TextStyle(
                  fontSize: 14,
                  color: darkGray,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: lightGray),
              pw.SizedBox(height: 10),

              // Items list
              pw.Text(
                "Productos Reservados:",
                style: pw.TextStyle(
                  fontSize: 12,
                  color: darkGray,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "${item['quantity']}x ${item['product_name']}",
                        style: pw.TextStyle(fontSize: 11, color: darkGray),
                      ),
                      pw.Text(
                        "S/${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}",
                        style: pw.TextStyle(fontSize: 11, color: darkGray),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: lightGray),
              pw.SizedBox(height: 10),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "TOTAL",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: darkGray,
                    ),
                  ),
                  pw.Text(
                    "S/${ticketData['total'].toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: successGreen,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // QR Code centered
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: lightGray, width: 2),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: ticketData['qr_data'],
                        width: 180,
                        height: 180,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      "Muestra este QR en bodega",
                      style: pw.TextStyle(fontSize: 10, color: lightGray),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  "Gracias por usar Chek",
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: primaryBlue,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _cancelOrder(BuildContext context, String orderId) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar Pedido"),
        content: const Text(
          "¿Estás seguro de que quieres cancelar este pedido?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final userId = await SessionService().getUserId();
    if (userId != null) {
      final success = await ApiService().cancelOrder(orderId, userId);
      if (context.mounted) Navigator.pop(context); // Close loading

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pedido cancelado"),
              backgroundColor: HomeColors.success,
            ),
          );
          Navigator.pop(context); // Close TicketScreen
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al cancelar"),
              backgroundColor: HomeColors.error,
            ),
          );
        }
      }
    } else {
      if (context.mounted) Navigator.pop(context); // Close loading if no user
    }
  }
}

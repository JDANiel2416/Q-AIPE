import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class TicketScreen extends StatelessWidget {
  final Map<String, dynamic> ticketData;

  const TicketScreen({Key? key, required this.ticketData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = ticketData['items'] as List;
    final total = ticketData['total'];
    final qrData = ticketData['qr_data'];
    final userName = ticketData['formatted_name'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Tu Ticket de Reserva"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // TICKET CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   const Icon(Icons.check_circle, color: Colors.green, size: 60),
                   const SizedBox(height: 16),
                   const Text(
                     "¡Reserva Confirmada!",
                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Cliente: $userName",
                     style: const TextStyle(fontSize: 16, color: Colors.grey),
                   ),
                   const Divider(height: 40),
                   
                   // Lista de productos
                   ListView.builder(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     itemCount: items.length,
                     itemBuilder: (context, index) {
                       final item = items[index];
                       return Padding(
                         padding: const EdgeInsets.symmetric(vertical: 4),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text("${item['quantity']}x ${item['product_name']}"),
                             Text("S/${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}"),
                           ],
                         ),
                       );
                     },
                   ),
                   
                   const Divider(height: 40),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                       Text("S/${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                     ],
                   ),
                   const SizedBox(height: 30),
                   
                   // QR CODE
                   QrImageView(
                     data: qrData,
                     version: QrVersions.auto,
                     size: 200.0,
                   ),
                   const SizedBox(height: 10),
                   const Text("Muestra este QR en bodega", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
             SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text("Volver al Inicio"),
                 style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
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
              
              ...items.map((item) => pw.Padding(
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
              )),
              
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
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
}

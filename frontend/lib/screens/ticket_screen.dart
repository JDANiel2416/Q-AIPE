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

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Header(level: 0, child: pw.Text("Comprobante de Reserva Q-AIPE")),
                pw.SizedBox(height: 20),
                pw.Text("Cliente: ${ticketData['formatted_name']}"),
                pw.Text("Total: S/${ticketData['total'].toStringAsFixed(2)}"),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: ticketData['qr_data'],
                  width: 200,
                  height: 200,
                ),
                pw.SizedBox(height: 20),
                pw.Text("Gracias por usar Q-AIPE"),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

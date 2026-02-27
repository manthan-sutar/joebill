import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/bill_tab.dart';

class PdfService {
  static Future<Uint8List> generateReceipt(BillTab tab) async {
    final pdf = pw.Document();
    final currFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dtFmt = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text("JOE'S CORNER",
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('BILL RECEIPT', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Divider(),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(tab.customerName),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:'),
                pw.Text(dtFmt.format((tab.closedAt ?? DateTime.now()).toLocal())),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Bill #:'),
                pw.Text('#${tab.id.toString().padLeft(4, '0')}'),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),

            // Items
            if (tab.items.isNotEmpty) ...[
              pw.Text('ITEMS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.SizedBox(height: 4),
              ...tab.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('${item.menuItemName} x${item.quantity}')),
                        pw.Text(currFmt.format(item.subtotal)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],

            // Games
            if (tab.gameSessions.isNotEmpty) ...[
              pw.Divider(),
              pw.Text('GAMES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.SizedBox(height: 4),
              ...tab.gameSessions.map((g) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                              '${g.gameName} (${g.durationMinutes?.toStringAsFixed(1) ?? 0} min)'),
                        ),
                        pw.Text(currFmt.format(g.totalCost ?? 0)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],

            pw.Divider(thickness: 1.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text(
                  currFmt.format(tab.subtotal),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment:'),
                pw.Text((tab.paymentMethod ?? '').toUpperCase()),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Thank you! Visit again.', style: pw.TextStyle(fontSize: 11))),
            pw.Center(child: pw.Text("Joe's Corner", style: pw.TextStyle(fontSize: 10))),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}

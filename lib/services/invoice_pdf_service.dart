import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/profile_service.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';

class InvoicePdfService {
  final BillService _billService = BillService();

  Future<Uint8List> buildPdf({
    required BillRecord bill,
    required UserProfile profile,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                profile.storeName.isNotEmpty ? profile.storeName : 'VoiceBill',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                bill.invoiceNumber > 0
                    ? 'Hóa đơn: ${_billService.formatInvoiceNumber(bill.invoiceNumber)}'
                    : 'Hóa đơn: ${shortId(bill.id).toUpperCase()}',
              ),
              pw.Text('Ngày: ${_formatDate(bill.createdAt)}'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: const ['Mặt hàng', 'SL', 'Giá', 'Thành tiền'],
                data: bill.items.map((item) {
                  return [
                    item.name,
                    '${item.quantity}',
                    formatCurrency(item.unitPrice),
                    formatCurrency(item.subtotal),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Tổng tiền: ${formatCurrency(bill.total)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              if (profile.accountNumber.isNotEmpty)
                pw.Text(
                  'Thanh toán: ${profile.bankName} - ${profile.accountNumber}',
                ),
              if (profile.accountName.isNotEmpty)
                pw.Text('Chủ TK: ${profile.accountName}'),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

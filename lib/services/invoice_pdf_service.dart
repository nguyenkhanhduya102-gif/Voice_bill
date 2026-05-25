import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/profile_service.dart';

class InvoicePdfService {
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
              pw.Text('Hoa don: ${bill.id.substring(0, 6).toUpperCase()}'),
              pw.Text('Ngay: ${_formatDate(bill.createdAt)}'),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: const ['Mat hang', 'SL', 'Gia', 'Thanh tien'],
                data: bill.items.map((item) {
                  final priceValue = _parsePriceToInt(item.price);
                  final total = priceValue * item.quantity;
                  return [
                    item.name,
                    '${item.quantity}',
                    _formatCurrency(priceValue),
                    _formatCurrency(total),
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
                  pw.Text(
                    'Tong cong: ${_formatCurrency(bill.total)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              if (profile.accountNumber.isNotEmpty)
                pw.Text(
                  'Thanh toan: ${profile.bankName} - ${profile.accountNumber}',
                ),
              if (profile.accountName.isNotEmpty)
                pw.Text('Chu TK: ${profile.accountName}'),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatCurrency(int value) {
    if (value <= 0) {
      return '0d';
    }
    final chars = value.toString().split('');
    final buffer = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      final positionFromEnd = chars.length - i;
      buffer.write(chars[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${buffer.toString()}d';
  }

  int _parsePriceToInt(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
}

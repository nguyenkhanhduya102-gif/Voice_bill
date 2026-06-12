import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';

class ExportService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> exportBillsToCsv() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .get();

    final bills = snap.docs.map(BillRecord.fromDoc).toList();

    final buffer = StringBuffer();

    buffer.writeln(
      'Số HĐ,Ngày,Trạng thái,Số mặt hàng,Thành tiền',
    );

    for (final bill in bills) {
      final dateText = bill.createdAt != null ? formatDate(bill.createdAt) : '';
      final statusText = bill.status == 'debt' ? 'Ghi nợ' : 'Đã thanh toán';
      final line = [
        bill.invoiceNumber > 0
            ? 'HD-${bill.invoiceNumber.toString().padLeft(6, '0')}'
            : bill.id,
        dateText,
        statusText,
        '${bill.items.length}',
        formatCurrency(bill.total),
      ].join(',');
      buffer.writeln(line);
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'hoadon_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

}

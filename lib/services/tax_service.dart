import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/tax_rules.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';

/// Doanh thu một tháng.
class MonthRevenue {
  final int month; // 1-12
  final int total;
  final int count;
  const MonthRevenue(this.month, this.total, this.count);
}

/// Gom doanh thu theo từng tháng (1-12) từ danh sách hóa đơn (thuần, dễ test).
List<MonthRevenue> aggregateByMonth(List<BillRecord> bills) {
  final totals = List<int>.filled(12, 0);
  final counts = List<int>.filled(12, 0);
  for (final b in bills) {
    final d = b.createdAt;
    if (d == null) continue;
    final i = d.month - 1;
    if (i < 0 || i > 11) continue;
    totals[i] += b.total;
    counts[i] += 1;
  }
  return [for (var i = 0; i < 12; i++) MonthRevenue(i + 1, totals[i], counts[i])];
}

/// Tổng hợp số liệu thuế cho một năm dương lịch.
class TaxYearSummary {
  final int nam;
  final int doanhThu;
  final int soHoaDon;
  final TaxTier bac;
  final TaxEstimate uocTinh;
  final IndustryRate nganh;
  final List<BillRecord> bills;

  const TaxYearSummary({
    required this.nam,
    required this.doanhThu,
    required this.soHoaDon,
    required this.bac,
    required this.uocTinh,
    required this.nganh,
    required this.bills,
  });

  NguongStatus get trangThai => trangThaiNguong(doanhThu);
  double get tyLe => tyLeNguong(doanhThu);
  DateTime get hanNopThongBao => hanNopThongBaoNam(nam);
}

class TaxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gom doanh thu của [nam] (theo `createdAt` của hóa đơn) và suy ra bậc thuế.
  /// Doanh thu = tổng `total` mọi hóa đơn trong năm (kể cả ghi nợ — đã phát sinh
  /// bán hàng nên vẫn tính doanh thu).
  Future<TaxYearSummary> tongHopNam(
    int nam, {
    IndustryRate nganh = phanPhoiHangHoa,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final start = Timestamp.fromDate(DateTime(nam, 1, 1));
    final end = Timestamp.fromDate(DateTime(nam + 1, 1, 1));

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bills')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt')
        .get();

    final bills = snap.docs.map(BillRecord.fromDoc).toList();
    final doanhThu = bills.fold<int>(0, (acc, b) => acc + b.total);
    final bac = xacDinhBac(doanhThu);

    return TaxYearSummary(
      nam: nam,
      doanhThu: doanhThu,
      soHoaDon: bills.length,
      bac: bac,
      uocTinh: uocTinhThue(bac: bac, doanhThuNam: doanhThu, nganh: nganh),
      nganh: nganh,
      bills: bills,
    );
  }

  /// Xuất Sổ doanh thu (Mẫu S1a) ra CSV, trả về đường dẫn file.
  Future<String> xuatSoDoanhThuS1a(TaxYearSummary summary) async {
    final buffer = StringBuffer();
    buffer.writeln('SO DOANH THU BAN HANG HOA DICH VU (Mau S1a-HKD)');
    buffer.writeln('Nam,${summary.nam}');
    buffer.writeln('');
    buffer.writeln('STT,Ngay,So hoa don,So mat hang,Doanh thu');

    var stt = 0;
    for (final bill in summary.bills) {
      stt += 1;
      final ngay = bill.createdAt != null ? formatDate(bill.createdAt) : '';
      final soHd = bill.invoiceNumber > 0
          ? 'HD-${bill.invoiceNumber.toString().padLeft(6, '0')}'
          : bill.id;
      buffer.writeln(
        [stt, ngay, soHd, bill.items.length, formatCurrency(bill.total)]
            .join(','),
      );
    }

    buffer.writeln('');
    buffer.writeln('Tong doanh thu,,,,${formatCurrency(summary.doanhThu)}');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'so_doanh_thu_S1a_${summary.nam}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }
}

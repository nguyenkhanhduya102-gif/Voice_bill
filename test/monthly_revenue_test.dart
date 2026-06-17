import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/tax_service.dart';

BillRecord _bill(int total, DateTime date) => BillRecord(
      id: 'x',
      items: const [],
      total: total,
      status: 'paid',
      createdAt: date,
    );

void main() {
  group('aggregateByMonth', () {
    test('luôn trả 12 tháng', () {
      final r = aggregateByMonth([]);
      expect(r.length, 12);
      expect(r.every((m) => m.total == 0 && m.count == 0), true);
    });

    test('gom tổng và số đơn đúng tháng', () {
      final r = aggregateByMonth([
        _bill(100, DateTime(2026, 1, 5)),
        _bill(200, DateTime(2026, 1, 20)),
        _bill(50, DateTime(2026, 3, 2)),
      ]);
      expect(r[0].total, 300); // tháng 1
      expect(r[0].count, 2);
      expect(r[2].total, 50); // tháng 3
      expect(r[2].count, 1);
      expect(r[1].total, 0); // tháng 2
    });

    test('bỏ qua hóa đơn không có ngày', () {
      final r = aggregateByMonth([
        BillRecord(
            id: 'a',
            items: const [],
            total: 999,
            status: 'paid',
            createdAt: null),
      ]);
      expect(r.fold<int>(0, (acc, m) => acc + m.total), 0);
    });
  });
}

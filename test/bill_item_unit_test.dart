import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/models/bill_models.dart';

void main() {
  group('BillItem.unit round-trip', () {
    test('toMap có unit khi không rỗng, bỏ khi rỗng', () {
      final withUnit = BillItem(
          name: 'Cam', quantity: 2, unitPrice: 10000, unit: 'kg');
      expect(withUnit.toMap()['unit'], 'kg');

      final noUnit = BillItem(name: 'Cam', quantity: 2, unitPrice: 10000);
      expect(noUnit.toMap().containsKey('unit'), false);
    });

    test('fromMap đọc unit, mặc định rỗng', () {
      final a = BillItem.fromMap({
        'name': 'Cam',
        'quantity': 2,
        'unitPrice': 10000,
        'unit': 'lon',
      });
      expect(a.unit, 'lon');

      final b = BillItem.fromMap({'name': 'Cam', 'quantity': 1, 'unitPrice': 5000});
      expect(b.unit, '');
    });
  });
}

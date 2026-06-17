import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/models/bill_models.dart';

void main() {
  group('paymentLabel', () {
    test('ghi nợ -> "Ghi nợ" bất kể method', () {
      expect(paymentLabel('debt', ''), 'Ghi nợ');
      expect(paymentLabel('debt', 'cash'), 'Ghi nợ');
    });
    test('đã thu tiền mặt', () {
      expect(paymentLabel('paid', 'cash'), 'Tiền mặt');
    });
    test('đã thu chuyển khoản', () {
      expect(paymentLabel('paid', 'transfer'), 'Chuyển khoản');
    });
    test('đã thu nhưng không rõ method -> "Đã thanh toán"', () {
      expect(paymentLabel('paid', ''), 'Đã thanh toán');
    });
  });
}

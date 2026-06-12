import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/services/product_service.dart';

void main() {
  group('aggregateStockItems', () {
    test('gộp dòng trùng tên trong cùng lô (cộng số lượng)', () {
      final agg = ProductService.aggregateStockItems([
        {'name': 'Táo', 'unit': 'kg', 'price': 20000, 'quantity': 2},
        {'name': 'táo', 'unit': 'kg', 'price': 25000, 'quantity': 3},
      ]);
      expect(agg.length, 1);
      final item = agg.values.first;
      expect(item['quantity'], 5); // 2 + 3
      expect(item['priceValue'], 25000); // lấy giá mới nhất > 0
    });

    test('giữ giá cũ nếu dòng sau giá 0', () {
      final agg = ProductService.aggregateStockItems([
        {'name': 'Cam', 'unit': 'kg', 'price': 18000, 'quantity': 1},
        {'name': 'Cam', 'unit': 'kg', 'price': 0, 'quantity': 1},
      ]);
      expect(agg.values.first['priceValue'], 18000);
      expect(agg.values.first['quantity'], 2);
    });

    test('các tên khác nhau giữ riêng', () {
      final agg = ProductService.aggregateStockItems([
        {'name': 'Táo', 'unit': 'kg', 'price': 20000, 'quantity': 1},
        {'name': 'Cam', 'unit': 'kg', 'price': 18000, 'quantity': 1},
      ]);
      expect(agg.length, 2);
    });

    test('bỏ tên rỗng, số lượng <=0 thành 1', () {
      final agg = ProductService.aggregateStockItems([
        {'name': '', 'unit': 'kg', 'price': 1000, 'quantity': 1},
        {'name': 'Muối', 'unit': 'gói', 'price': 5000, 'quantity': 0},
      ]);
      expect(agg.length, 1);
      expect(agg.values.first['quantity'], 1);
    });

    test('đọc priceValue hoặc price', () {
      final agg = ProductService.aggregateStockItems([
        {'name': 'Đường', 'unit': 'kg', 'priceValue': 22000, 'quantity': 1},
      ]);
      expect(agg.values.first['priceValue'], 22000);
    });
  });
}

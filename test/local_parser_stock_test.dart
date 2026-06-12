import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/services/local_parser_service.dart';

void main() {
  final parser = LocalParserService();

  Map<String, dynamic> one(String input) {
    final r = parser.parseStockItems(input);
    expect(r, isNotEmpty, reason: 'Không parse được: "$input"');
    return r.first;
  }

  group('parseStockItems - cơ bản', () {
    test('tên + đơn vị dính số + giá', () {
      final m = one('táo 1kg 20000');
      expect(m['name'], 'Táo');
      expect(m['unit'], 'kg');
      expect(m['price'], 20000);
      expect(m['quantity'], 1);
    });

    test('số lượng + đơn vị + giá', () {
      final m = one('sting đỏ 2 thùng 150000');
      expect(m['name'], 'Sting Đỏ');
      expect(m['unit'], 'thùng');
      expect(m['quantity'], 2);
      expect(m['price'], 150000);
    });

    test('định dạng phẩy', () {
      final m = one('Táo, 1 kg, 20000');
      expect(m['name'], 'Táo');
      expect(m['unit'], 'kg');
      expect(m['price'], 20000);
    });

    test('định dạng pipe', () {
      final m = one('Táo | 1 cân | 50.000đ');
      expect(m['name'], 'Táo');
      expect(m['price'], 50000);
    });
  });

  group('parseStockItems - số bằng chữ & giá nói', () {
    test('giá viết tắt k', () {
      final m = one('cocacola 2 lốc 90k');
      expect(m['name'], 'Cocacola');
      expect(m['unit'], 'lốc');
      expect(m['quantity'], 2);
      expect(m['price'], 90000);
    });

    test('số lượng và giá bằng chữ', () {
      final m = one('sting đỏ ba thùng một trăm năm mươi nghìn');
      expect(m['name'], 'Sting Đỏ');
      expect(m['unit'], 'thùng');
      expect(m['quantity'], 3);
      expect(m['price'], 150000);
    });

    test('giá nghìn', () {
      final m = one('nước mắm 1 chai 35 nghìn');
      expect(m['unit'], 'chai');
      expect(m['price'], 35000);
    });
  });

  group('parseStockItems - bỏ từ thừa & nhiều món', () {
    test('bỏ từ ra lệnh', () {
      final m = one('nhập thêm 2 lốc cocacola 90k');
      expect(m['name'], 'Cocacola');
      expect(m['quantity'], 2);
      expect(m['price'], 90000);
    });

    test('tách nhiều món bằng "và"', () {
      final r = parser.parseStockItems('táo 1kg 20000 và cam 1kg 18000');
      expect(r.length, 2);
      expect(r[0]['name'], 'Táo');
      expect(r[1]['name'], 'Cam');
      expect(r[1]['price'], 18000);
    });

    test('tách nhiều món bằng ;', () {
      final r = parser.parseStockItems('táo 1kg 20000; cam 1kg 18000');
      expect(r.length, 2);
    });
  });

  group('parseStockItems - thiếu thông tin', () {
    test('không có giá -> price 0', () {
      final m = one('táo 2 thùng');
      expect(m['name'], 'Táo');
      expect(m['unit'], 'thùng');
      expect(m['quantity'], 2);
      expect(m['price'], 0);
    });

    test('không có đơn vị -> mặc định cái', () {
      final m = one('bút 5000');
      expect(m['name'], 'Bút');
      expect(m['unit'], 'cái');
      expect(m['price'], 5000);
    });
  });
}

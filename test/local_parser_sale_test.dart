import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/services/local_parser_service.dart';

void main() {
  final parser = LocalParserService();

  Map<String, dynamic> one(String input) {
    final r = parser.parseSaleItems(input);
    expect(r, isNotEmpty, reason: 'Không parse được: "$input"');
    return r.first;
  }

  group('parseSaleItems - số lượng đứng trước + đơn vị', () {
    test('"2 quả cam" -> cam, SL 2, giá 0', () {
      final m = one('2 quả cam');
      expect(m['name'], 'Cam');
      expect(m['quantity'], 2);
      expect(m['price'], 0);
    });

    test('"ba lon bia tiger" -> bia tiger, SL 3', () {
      final m = one('ba lon bia tiger');
      expect(m['name'], 'Bia Tiger');
      expect(m['quantity'], 3);
      expect(m['price'], 0);
    });
  });

  group('parseSaleItems - có giá', () {
    test('"cam 2 15000"', () {
      final m = one('cam 2 15000');
      expect(m['name'], 'Cam');
      expect(m['quantity'], 2);
      expect(m['price'], 15000);
    });

    test('định dạng phẩy "Táo, 2, 15000"', () {
      final m = one('Táo, 2, 15000');
      expect(m['name'], 'Táo');
      expect(m['quantity'], 2);
      expect(m['price'], 15000);
    });

    test('giá viết tắt "2 chai trà sữa 35k"', () {
      final m = one('2 chai trà sữa 35k');
      expect(m['name'], 'Trà Sữa');
      expect(m['quantity'], 2);
      expect(m['price'], 35000);
    });
  });

  group('parseSaleItems - bỏ từ thừa & nhiều món', () {
    test('"bán cho 2 quả cam"', () {
      final m = one('bán cho 2 quả cam');
      expect(m['name'], 'Cam');
      expect(m['quantity'], 2);
    });

    test('nhiều món bằng "và"', () {
      final r = parser.parseSaleItems('2 quả cam và 3 lon bia');
      expect(r.length, 2);
      expect(r[0]['name'], 'Cam');
      expect(r[0]['quantity'], 2);
      expect(r[1]['name'], 'Bia');
      expect(r[1]['quantity'], 3);
    });
  });

  group('parseSaleItems - chỉ tên', () {
    test('"cam" -> SL 1, giá 0', () {
      final m = one('cam');
      expect(m['name'], 'Cam');
      expect(m['quantity'], 1);
      expect(m['price'], 0);
    });
  });
}

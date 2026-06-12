import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/utils/vietnamese_number.dart';

void main() {
  group('parseVietnameseNumber - chữ số', () {
    test('số nguyên thuần', () {
      expect(parseVietnameseNumber('15000'), 15000);
      expect(parseVietnameseNumber('150000'), 150000);
    });
    test('có dấu ngăn cách hàng nghìn', () {
      expect(parseVietnameseNumber('150.000'), 150000);
      expect(parseVietnameseNumber('150,000'), 150000);
      expect(parseVietnameseNumber('1.234.567'), 1234567);
    });
    test('viết tắt k / tr', () {
      expect(parseVietnameseNumber('15k'), 15000);
      expect(parseVietnameseNumber('150 nghìn'), 150000);
      expect(parseVietnameseNumber('150 ngàn'), 150000);
      expect(parseVietnameseNumber('1tr'), 1000000);
      expect(parseVietnameseNumber('1 triệu'), 1000000);
    });
    test('có ký hiệu tiền', () {
      expect(parseVietnameseNumber('15.000đ'), 15000);
      expect(parseVietnameseNumber('150000 đồng'), 150000);
    });
  });

  group('parseVietnameseNumber - số bằng chữ', () {
    test('0-10', () {
      expect(parseVietnameseNumber('không'), 0);
      expect(parseVietnameseNumber('ba'), 3);
      expect(parseVietnameseNumber('mười'), 10);
    });
    test('chục', () {
      expect(parseVietnameseNumber('mười lăm'), 15);
      expect(parseVietnameseNumber('hai mươi'), 20);
      expect(parseVietnameseNumber('hai mươi lăm'), 25);
      expect(parseVietnameseNumber('năm mươi'), 50);
    });
    test('trăm', () {
      expect(parseVietnameseNumber('một trăm'), 100);
      expect(parseVietnameseNumber('một trăm năm mươi'), 150);
      expect(parseVietnameseNumber('một trăm lẻ năm'), 105);
      expect(parseVietnameseNumber('hai trăm mười lăm'), 215);
    });
    test('nghìn / triệu bằng chữ', () {
      expect(parseVietnameseNumber('năm mươi nghìn'), 50000);
      expect(parseVietnameseNumber('hai trăm nghìn'), 200000);
      expect(parseVietnameseNumber('một trăm năm mươi nghìn'), 150000);
      expect(parseVietnameseNumber('một triệu'), 1000000);
    });
    test('rưỡi', () {
      expect(parseVietnameseNumber('một triệu rưỡi'), 1500000);
      expect(parseVietnameseNumber('trăm rưỡi'), 150);
    });
    test('hỗn hợp chữ số + chữ', () {
      expect(parseVietnameseNumber('150 nghìn'), 150000);
      expect(parseVietnameseNumber('2 triệu'), 2000000);
    });
  });

  group('parseVietnameseNumber - không hợp lệ', () {
    test('chuỗi không có số', () {
      expect(parseVietnameseNumber('táo'), null);
      expect(parseVietnameseNumber(''), null);
      expect(parseVietnameseNumber('   '), null);
    });
  });
}

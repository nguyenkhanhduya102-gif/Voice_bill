import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voice_bill/utils/price_parser.dart' as price_parser;

class ProductItem {
  final String id;
  final String name;
  final String unit;

  /// Giá, đơn vị đồng (int). Nguồn sự thật duy nhất cho tiền; định dạng
  /// "15.000đ" chỉ làm ở tầng hiển thị.
  final int priceValue;
  final int stock;

  const ProductItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceValue,
    required this.stock,
  });

  factory ProductItem.fromMap(String id, Map<String, dynamic> data) {
    // Ưu tiên priceValue (int). Đọc dữ liệu cũ: rơi về 'price' dạng chuỗi.
    final int priceValue = (data['priceValue'] as num?)?.toInt() ??
        parsePriceToInt((data['price'] ?? '').toString());
    return ProductItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      priceValue: priceValue,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'priceValue': priceValue,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static int parsePriceToInt(String price) {
    return price_parser.parsePriceToInt(price);
  }
}

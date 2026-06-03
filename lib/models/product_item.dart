import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voice_bill/utils/price_parser.dart' as price_parser;

class ProductItem {
  final String id;
  final String name;
  final String unit;
  final String price;
  final int priceValue;
  final int stock;

  const ProductItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.priceValue,
    required this.stock,
  });

  factory ProductItem.fromMap(String id, Map<String, dynamic> data) {
    final priceText = (data['price'] ?? '').toString();
    final int priceValue =
        (data['priceValue'] as num?)?.toInt() ?? parsePriceToInt(priceText);
    return ProductItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      price: priceText,
      priceValue: priceValue,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'price': price,
      'priceValue': priceValue,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static int parsePriceToInt(String price) {
    return price_parser.parsePriceToInt(price);
  }
}

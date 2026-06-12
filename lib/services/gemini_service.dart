import 'package:cloud_functions/cloud_functions.dart';


class GeminiService {
  
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  bool get hasKey => true;
  Future<List<Map<String, dynamic>>> parseSaleItems(
    String text, {
    List<Map<String, dynamic>> products = const [],
  }) async {
    final result = await _functions.httpsCallable('parseSale').call<Map>({
      'text': text,
      'products': products,
    });
    return _itemsFrom(result.data);
  }

  Future<List<Map<String, dynamic>>> parseStockItems(
    String text, {
    List<Map<String, dynamic>> products = const [],
  }) async {
    final result = await _functions.httpsCallable('parseStock').call<Map>({
      'text': text,
      'products': products,
    });
    return _itemsFrom(result.data);
  }

  List<Map<String, dynamic>> _itemsFrom(Object? data) {
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return [];
  }
}

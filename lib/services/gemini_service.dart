import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel? _model;

  bool get hasKey => _apiKey.isNotEmpty;

  GenerativeModel _getModel() {
    return _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> parseSaleItems(String text) async {
    final prompt = {
      'task': 'parse_sale_items',
      'input': text,
      'rules': [
        'Return JSON array of items with name, quantity, price',
        'quantity and price are integers',
        'If missing quantity or price, set to 1 and 0',
      ],
      'examples': [
        {
          'input': 'tao 2 15000, cam 1 12000',
          'output': [
            {'name': 'Táo', 'quantity': 2, 'price': 15000},
            {'name': 'Cam', 'quantity': 1, 'price': 12000},
          ],
        },
      ],
    };

    final response = await _getModel().generateContent([
      Content.text(jsonEncode(prompt)),
    ]);

    final textOut = response.text ?? '[]';
    final decoded = jsonDecode(textOut);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> parseStockItems(String text) async {
    final prompt = {
      'task': 'parse_stock_items',
      'input': text,
      'rules': [
        'Return JSON array of items with name, unit, price',
        'price is integer',
        'If missing unit or price, set unit to "cai" and price to 0',
      ],
      'examples': [
        {
          'input': 'tao 1kg 20000, cam 1kg 18000',
          'output': [
            {'name': 'Táo', 'unit': 'kg', 'price': 20000},
            {'name': 'Cam', 'unit': 'kg', 'price': 18000},
          ],
        },
      ],
    };

    final response = await _getModel().generateContent([
      Content.text(jsonEncode(prompt)),
    ]);

    final textOut = response.text ?? '[]';
    final decoded = jsonDecode(textOut);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return [];
  }
}

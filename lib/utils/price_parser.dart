int parsePriceToInt(String price) {
  final digits = price.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

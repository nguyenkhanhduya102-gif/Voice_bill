String formatCurrency(int value) {
  if (value <= 0) {
    return '0đ';
  }
  final chars = value.toString().split('');
  final buffer = StringBuffer();
  for (int i = 0; i < chars.length; i++) {
    final positionFromEnd = chars.length - i;
    buffer.write(chars[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '${buffer.toString()}đ';
}

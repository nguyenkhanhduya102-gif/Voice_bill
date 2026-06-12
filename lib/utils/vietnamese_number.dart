/// Phân tích số tiếng Việt (cả chữ số lẫn số viết bằng chữ) thành int.
///
/// Hỗ trợ các dạng phổ biến ở tạp hóa:
///   "15000", "150.000", "150,000"           -> 150000
///   "15k", "150 nghìn", "150 ngàn"           -> 15000 / 150000
///   "1 triệu", "1tr", "một triệu rưỡi"        -> 1000000 / 1500000
///   "ba", "mười lăm", "hai mươi lăm"          -> 3 / 15 / 25
///   "một trăm năm mươi nghìn"                -> 150000
///
/// Trả về null nếu không tìm thấy thành phần số nào.
int? parseVietnameseNumber(String input) {
  var s = input.toLowerCase().trim();
  if (s.isEmpty) return null;

  // Bỏ ký hiệu/chữ tiền tệ.
  s = s.replaceAll('₫', ' ').replaceAll('đồng', ' ').replaceAll('đ', ' ');

  // Viết tắt: "15k" -> "15 nghìn", "1tr" -> "1 triệu".
  s = s.replaceAllMapped(
      RegExp(r'(\d)\s*k(?![a-zà-ỹ])'), (m) => '${m[1]} nghìn ');
  s = s.replaceAllMapped(
      RegExp(r'(\d)\s*tr(?![a-zà-ỹ])'), (m) => '${m[1]} triệu ');

  // Bỏ dấu chấm/phẩy ngăn cách hàng nghìn nằm giữa các chữ số (1.234.567).
  final sep = RegExp(r'(\d)[.,](\d)');
  while (sep.hasMatch(s)) {
    s = s.replaceAllMapped(sep, (m) => '${m[1]}${m[2]}');
  }

  final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return null;

  const small = <String, int>{
    'không': 0, 'linh': 0, 'lẻ': 0,
    'một': 1, 'mốt': 1,
    'hai': 2, 'ba': 3,
    'bốn': 4, 'tư': 4,
    'năm': 5, 'lăm': 5, 'nhăm': 5,
    'sáu': 6, 'bảy': 7, 'bẩy': 7,
    'tám': 8, 'chín': 9,
  };

  int total = 0; // đã chốt theo nghìn/triệu/tỷ
  int section = 0; // phần trăm/chục trong cụm < 1000
  int unit = 0; // chữ số lẻ đang chờ
  int lastScale = 1; // scale gần nhất, phục vụ "rưỡi"
  bool found = false;

  for (final t in tokens) {
    final n = int.tryParse(t);
    if (n != null) {
      if (n >= 1000) {
        total += n; // đã là giá trị đầy đủ
      } else {
        unit += n;
      }
      lastScale = 1;
      found = true;
      continue;
    }

    if (small.containsKey(t)) {
      unit += small[t]!;
      found = true;
      continue;
    }

    switch (t) {
      case 'mười':
        section += 10;
        lastScale = 10;
        found = true;
        break;
      case 'mươi':
        section += unit * 10;
        unit = 0;
        lastScale = 10;
        found = true;
        break;
      case 'trăm':
        section += (unit == 0 ? 1 : unit) * 100;
        unit = 0;
        lastScale = 100;
        found = true;
        break;
      case 'nghìn':
      case 'ngàn':
        final v = section + unit;
        total += (v == 0 ? 1 : v) * 1000;
        section = 0;
        unit = 0;
        lastScale = 1000;
        found = true;
        break;
      case 'triệu':
        final v = section + unit;
        total += (v == 0 ? 1 : v) * 1000000;
        section = 0;
        unit = 0;
        lastScale = 1000000;
        found = true;
        break;
      case 'tỷ':
      case 'tỉ':
        final v = section + unit;
        total += (v == 0 ? 1 : v) * 1000000000;
        section = 0;
        unit = 0;
        lastScale = 1000000000;
        found = true;
        break;
      case 'rưỡi':
        if (lastScale >= 1000) {
          total += lastScale ~/ 2;
        } else {
          unit += lastScale ~/ 2;
        }
        found = true;
        break;
      default:
        // Token không phải số -> bỏ qua (cho phép từ thừa xen kẽ).
        break;
    }
  }

  if (!found) return null;
  return total + section + unit;
}

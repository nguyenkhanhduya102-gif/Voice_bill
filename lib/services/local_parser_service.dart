import 'package:voice_bill/utils/vietnamese_number.dart';

class LocalParserService {
  // ---------------------------------------------------------------------------
  // BÁN HÀNG (nâng ngang nhập hàng: số đứng trước, đơn vị, bỏ từ thừa, giá tùy chọn)
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> parseSaleItems(String text) {
    final items = <Map<String, dynamic>>[];
    for (final entry in _splitItems(text)) {
      final cleaned = _removeFillers(entry).trim();
      if (cleaned.isEmpty) continue;
      final parsed = _parseSaleEntry(cleaned);
      if (parsed != null) items.add(parsed);
    }
    return items;
  }

  /// Bóc một câu bán hàng -> {name, quantity, price}. Giá có thể thiếu (=0),
  /// khi đó tầng UI sẽ tự điền giá từ kho. Hỗ trợ "2 quả cam", "ba lon bia",
  /// "cam 2 15000", "Táo, 2, 15000".
  Map<String, dynamic>? _parseSaleEntry(String raw) {
    var s = raw.replaceAll(',', ' ');
    s = _separateDigitUnit(s);
    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    // 1) GIÁ: cụm số cuối, chỉ nhận khi "giống giá" (>=1000 hoặc có k/nghìn/đ).
    var working = List<String>.from(tokens);
    int price = 0;
    final tail = _extractTrailingNumber(working);
    if (tail != null && _isPriceLike(tail.text, tail.value)) {
      price = tail.value;
      working = working.sublist(0, tail.start);
    }

    // 2) SỐ LƯỢNG + ĐƠN VỊ.
    final consumed = <int>{};
    int qty = 1;
    final unitIdx = working.indexWhere((t) => _isUnit(t));
    if (unitIdx >= 0) {
      consumed.add(unitIdx); // bỏ đơn vị khỏi tên (bán hàng không lưu đơn vị)
      // số lượng đứng ngay trước đơn vị: "2 quả", "ba lon"
      if (unitIdx > 0 && _isNumberToken(working[unitIdx - 1])) {
        int hi = unitIdx - 1, lo = hi;
        while (lo - 1 >= 0 && _isNumberToken(working[lo - 1])) {
          lo--;
        }
        final v = parseVietnameseNumber(working.sublist(lo, hi + 1).join(' '));
        if (v != null && v > 0) {
          qty = v;
          for (var k = lo; k <= hi; k++) {
            consumed.add(k);
          }
        }
      }
    } else {
      // không có đơn vị: số lượng = số đầu tiên gặp được (vd "cam 2", "2 cam").
      for (var i = 0; i < working.length; i++) {
        if (!_isNumberToken(working[i])) continue;
        final v = parseVietnameseNumber(working[i]);
        if (v != null && v > 0) {
          qty = v;
          consumed.add(i);
          break;
        }
      }
    }

    // 3) TÊN = phần còn lại.
    final name = [
      for (var i = 0; i < working.length; i++)
        if (!consumed.contains(i)) working[i]
    ].join(' ').trim();
    if (name.isEmpty) return null;

    return {
      'name': _capitalizeName(name),
      'quantity': qty <= 0 ? 1 : qty,
      'price': price < 0 ? 0 : price,
    };
  }

  // ---------------------------------------------------------------------------
  // NHẬP HÀNG (Phase 1: số bằng chữ, bỏ từ thừa, đơn vị rộng, quantity, tách món)
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> parseStockItems(String text) {
    final items = <Map<String, dynamic>>[];
    for (final entry in _splitItems(text)) {
      final cleaned = _removeFillers(entry).trim();
      if (cleaned.isEmpty) continue;
      final parsed = _parseStockEntry(cleaned);
      if (parsed != null) items.add(parsed);
    }
    return items;
  }

  /// Tách nhiều mặt hàng: theo xuống dòng, ';', và các từ nối " và "/" rồi ".
  /// KHÔNG tách bằng dấu phẩy (phẩy thường ngăn cách trường trong một món).
  List<String> _splitItems(String text) {
    return text
        .split(RegExp(r'[\n;]|\s+và\s+|\s+rồi\s+', caseSensitive: false))
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  /// Bỏ các từ ra lệnh thừa ở đầu/giữa câu (nhập, thêm, cho, lấy, mua...).
  String _removeFillers(String s) {
    const fillers = {
      'nhập', 'nhâp', 'thêm', 'them', 'cho', 'lấy', 'lay', 'mua', 'vào', 'vô',
      'kho', 'dùm', 'giùm', 'gium', 'hàng', 'ơi', 'nhé', 'nha',
      'bán', 'ban', 'tính', 'tinh', 'ghi', 'lại', 'với', 'voi',
    };
    final tokens = s.split(RegExp(r'\s+')).where((t) {
      return !fillers.contains(t.toLowerCase());
    });
    return tokens.join(' ');
  }

  Map<String, dynamic>? _parseStockEntry(String raw) {
    // Định dạng pipe rõ ràng: "Táo | 1 cân | 50.000đ"
    if (raw.contains('|')) {
      final parts = raw.split('|').map((e) => e.trim()).toList();
      if (parts.length < 2) return null;
      final qu = _splitQtyUnit(parts[1]);
      final price = parts.length > 2
          ? (parseVietnameseNumber(parts.sublist(2).join(' ')) ?? 0)
          : 0;
      return _makeStock(parts[0], qu.unit, price, qu.qty);
    }

    // Chuẩn hóa: phẩy -> khoảng trắng (ngăn cách trường), tách số dính đơn vị.
    var s = raw.replaceAll(',', ' ');
    s = _separateDigitUnit(s);
    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    // 1) Tách GIÁ: cụm số ở cuối, chỉ nhận khi "giống giá" (>=1000 hoặc có
    //    đơn vị tiền k/nghìn/triệu/đ). Số nhỏ lẻ coi là số lượng, không phải giá.
    var working = List<String>.from(tokens);
    int price = 0;
    final tail = _extractTrailingNumber(working);
    if (tail != null && _isPriceLike(tail.text, tail.value)) {
      price = tail.value;
      working = working.sublist(0, tail.start);
    }

    // 2) Tìm ĐƠN VỊ.
    int unitIdx = working.indexWhere((t) => _isUnit(t));
    String unit = unitIdx >= 0 ? working[unitIdx] : 'cái';

    // 3) SỐ LƯỢNG: cụm số ngay trước đơn vị (nếu có).
    int qty = 1;
    final consumed = <int>{};
    if (unitIdx >= 0) consumed.add(unitIdx);
    if (unitIdx > 0 && _isNumberToken(working[unitIdx - 1])) {
      int hi = unitIdx - 1, lo = hi;
      while (lo - 1 >= 0 && _isNumberToken(working[lo - 1])) {
        lo--;
      }
      final v = parseVietnameseNumber(working.sublist(lo, hi + 1).join(' '));
      if (v != null && v > 0) {
        qty = v;
        for (var k = lo; k <= hi; k++) {
          consumed.add(k);
        }
      }
    }

    // 4) TÊN: các token còn lại (bỏ đơn vị + số lượng).
    final nameTokens = <String>[];
    for (var i = 0; i < working.length; i++) {
      if (consumed.contains(i)) continue;
      nameTokens.add(working[i]);
    }
    final name = nameTokens.join(' ').trim();
    if (name.isEmpty) return null;

    return _makeStock(name, unit, price, qty);
  }

  Map<String, dynamic> _makeStock(String name, String unit, int price, int qty) {
    final cleanName = _capitalizeName(name.trim());
    final cleanUnit = unit.trim().isEmpty ? 'cái' : unit.trim().toLowerCase();
    return {
      'name': cleanName,
      'unit': cleanUnit,
      'price': price < 0 ? 0 : price,
      'quantity': qty <= 0 ? 1 : qty,
    };
  }

  /// Tách "1 cân" / "2thùng" thành (qty, unit). Nếu chỉ có đơn vị -> qty 1.
  ({int qty, String unit}) _splitQtyUnit(String field) {
    final s = _separateDigitUnit(field.trim());
    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    int qty = 1;
    String unit = '';
    for (final t in tokens) {
      if (_isUnit(t)) {
        unit = t;
      } else if (_isNumberToken(t)) {
        final v = parseVietnameseNumber(t);
        if (v != null && v > 0) qty = v;
      } else if (unit.isEmpty) {
        unit = t; // đơn vị lạ không có trong danh sách -> vẫn nhận
      }
    }
    return (qty: qty, unit: unit.isEmpty ? 'cái' : unit);
  }

  // --- Tiện ích số/đơn vị cho nhập hàng -------------------------------------

  ({int value, int start, String text})? _extractTrailingNumber(
      List<String> tokens) {
    int i = tokens.length - 1;
    while (i >= 0 && !_isNumberToken(tokens[i])) {
      i--;
    }
    if (i < 0) return null;
    int lo = i;
    while (lo - 1 >= 0 && _isNumberToken(tokens[lo - 1])) {
      // Hai CHỮ SỐ TRẦN liền nhau (vd "2 15000") là hai số riêng (số lượng +
      // giá), không gộp thành một cụm. Số viết bằng chữ thì vẫn gộp.
      if (_isPureDigit(tokens[lo - 1]) && _isPureDigit(tokens[lo])) break;
      lo--;
    }
    final text = tokens.sublist(lo, i + 1).join(' ');
    final value = parseVietnameseNumber(text);
    if (value == null) return null;
    return (value: value, start: lo, text: text);
  }

  bool _isPriceLike(String runText, int value) {
    if (value >= 1000) return true;
    final r = runText.toLowerCase();
    return r.contains('nghìn') ||
        r.contains('ngàn') ||
        r.contains('triệu') ||
        r.contains('tỷ') ||
        r.contains('tỉ') ||
        r.contains('k') ||
        r.contains('đ') ||
        r.contains('₫');
  }

  static const _numberWords = {
    'không', 'lẻ', 'linh', 'một', 'mốt', 'hai', 'ba', 'bốn', 'tư',
    'năm', 'lăm', 'nhăm', 'sáu', 'bảy', 'bẩy', 'tám', 'chín',
    'mười', 'mươi', 'trăm', 'nghìn', 'ngàn', 'triệu', 'tỷ', 'tỉ', 'rưỡi',
  };

  bool _isNumberToken(String t) {
    final c = t.toLowerCase();
    if (_numberWords.contains(c)) return true;
    return _isPureDigit(t);
  }

  /// Token chỉ gồm chữ số (kèm dấu ngăn cách/k/đ), KHÔNG phải số viết bằng chữ.
  bool _isPureDigit(String t) {
    final cleaned = t.toLowerCase().replaceAll(RegExp(r'[.,kđ₫]'), '');
    return cleaned.isNotEmpty && int.tryParse(cleaned) != null;
  }

  // Danh sách đơn vị mở rộng (T1.5). Sắp xếp dài trước để tách số dính đơn vị.
  static const _units = [
    'kilogam', 'kilôgam', 'gram', 'gam', 'kg', 'kí', 'ki', 'g',
    'lít', 'lit', 'ml', 'l',
    'thùng', 'thung', 'hộp', 'hop', 'lốc', 'loc', 'vỉ', 'vi', 'két', 'ket',
    'chai', 'lon', 'gói', 'goi', 'bịch', 'bich', 'túi', 'tui', 'bao',
    'bó', 'bo', 'cây', 'cay', 'ổ', 'quả', 'qua', 'trái', 'trai',
    'cuộn', 'cuon', 'đôi', 'set', 'cặp', 'cap', 'vại', 'vai',
    'cái', 'cai', 'chiếc', 'chiec', 'con',
  ];

  static final Set<String> _unitSet = _units.toSet();

  bool _isUnit(String t) => _unitSet.contains(t.toLowerCase());

  static final RegExp _digitUnitRegExp = RegExp(
    '(\\d)\\s*(${(_units.toList()..sort((a, b) => b.length - a.length)).join('|')})\\b',
    caseSensitive: false,
  );

  /// "1kg" -> "1 kg", "2thùng" -> "2 thùng".
  String _separateDigitUnit(String s) {
    return s.replaceAllMapped(_digitUnitRegExp, (m) => '${m[1]} ${m[2]}');
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý chế độ sáng/tối toàn app, có lưu lựa chọn người dùng.
///
/// Dùng như một ValueNotifier: MaterialApp lắng nghe để đổi themeMode;
/// nút toggle trong Profile gọi [toggle]/[setMode].
class ThemeController extends ValueNotifier<ThemeMode> {
  // Mặc định giao diện SÁNG (dễ nhìn cho phần đông người dùng lớn tuổi).
  ThemeController() : super(ThemeMode.light);

  static const _prefKey = 'theme_mode';

  /// Nạp lựa chọn đã lưu (gọi 1 lần lúc khởi động).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_prefKey)) {
        case 'dark':
          value = ThemeMode.dark;
          break;
        case 'system':
          value = ThemeMode.system;
          break;
        default:
          value = ThemeMode.light;
      }
    } catch (_) {
      value = ThemeMode.light;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {
      // Không lưu được thì vẫn áp dụng cho phiên hiện tại.
    }
  }

  /// Đảo nhanh giữa sáng và tối (dựa trên brightness đang hiển thị).
  Future<void> toggle(Brightness current) {
    return setMode(
      current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

/// Instance dùng chung toàn app.
final themeController = ThemeController();

/// Điều chỉnh cỡ chữ toàn app — cho người lớn tuổi/mắt kém bật "Chữ lớn".
/// 1.0 = bình thường, 1.3 = lớn. Có lưu lựa chọn.
class TextScaleController extends ValueNotifier<double> {
  TextScaleController() : super(normal);

  static const _prefKey = 'text_scale';
  static const double normal = 1.0;
  static const double large = 1.3;

  bool get isLarge => value >= large;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_prefKey);
      if (v != null && v > 0) value = v;
    } catch (_) {
      value = normal;
    }
  }

  Future<void> setLarge(bool enabled) async {
    value = enabled ? large : normal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, value);
    } catch (_) {
      // Không lưu được thì vẫn áp dụng cho phiên hiện tại.
    }
  }
}

/// Instance dùng chung toàn app.
final textScaleController = TextScaleController();

/// Theo dõi đã xem hướng dẫn ban đầu chưa (hiện onboarding cho lần đầu mở app).
class OnboardingController extends ValueNotifier<bool> {
  OnboardingController() : super(false); // false = chưa xem

  static const _prefKey = 'onboarding_seen';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      value = false;
    }
  }

  Future<void> markSeen() async {
    value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {
      // Không lưu được thì phiên sau hiện lại — chấp nhận được.
    }
  }
}

/// Instance dùng chung toàn app.
final onboardingController = OnboardingController();

/// Theo dõi đã xem chỉ dẫn trên màn hình (coach marks) lần đầu vào màn chính chưa.
class CoachController extends ValueNotifier<bool> {
  CoachController() : super(false); // false = chưa xem

  static const _prefKey = 'coach_seen';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      value = false;
    }
  }

  Future<void> markSeen() async {
    value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {
      // bỏ qua
    }
  }
}

/// Instance dùng chung toàn app.
final coachController = CoachController();

/// Bảng màu ngữ nghĩa theo brightness — thay cho việc hardcode Colors.white /
/// Colors.black ở từng widget. Dùng: `context.surface`, `context.textPrimary`...
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Nền màn hình.
  Color get scaffoldBg => isDark ? const Color(0xFF121212) : Colors.white;

  /// Nền thẻ/khối nổi trên nền màn hình.
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  /// Nền phụ (ô input, khối xám nhạt).
  Color get surfaceAlt =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7F5);

  /// Viền nhạt.
  Color get border =>
      isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEDEDED);

  /// Chữ chính.
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1D1D1D);

  /// Chữ phụ.
  Color get textSecondary =>
      isDark ? Colors.white70 : const Color(0xFF515151);

  /// Chữ mờ (gợi ý, placeholder). Đậm hơn mặc định để người lớn tuổi đọc được
  /// (38% quá nhạt, không đạt tương phản).
  Color get textMuted => isDark ? Colors.white70 : Colors.black54;

  /// Màu thương hiệu (giữ nguyên ở cả 2 chế độ, sáng hơn chút ở dark).
  Color get brand => isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
}

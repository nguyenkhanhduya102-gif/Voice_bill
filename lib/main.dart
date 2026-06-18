import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:voice_bill/pages/auth_gate.dart';
import 'package:voice_bill/firebase_options.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:device_preview/device_preview.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  await themeController.load();
  await textScaleController.load();
  await coachController.load();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, 
      builder: (context) => const VoiceBillApp(),
    ),
  );
}

class VoiceBillApp extends StatelessWidget {
  const VoiceBillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hóa Đơn Giọng Nói',
          
          
          useInheritedMediaQuery: true, 
          locale: DevicePreview.locale(context), 
          builder: (context, child) {
            
            return ValueListenableBuilder<double>(
              valueListenable: textScaleController,
              builder: (context, scale, _) {
                final mq = MediaQuery.of(context);
                
                
                final updatedChild = DevicePreview.appBuilder(context, child);

                return MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                  child: updatedChild ?? const SizedBox.shrink(),
                );
              },
            );
          },
          
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}


const Color _primaryGreen = Color(0xFF2E7D32);
const Color _textPrimary = Color(0xFF1D1D1D);
const Color _textSecondary = Color(0xFF616161);

ThemeData _buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      brightness: Brightness.light,
      primary: _primaryGreen,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7F5),
    primaryColor: _primaryGreen,
    textTheme: _textTheme(Brightness.light),
    inputDecorationTheme: _inputDecorationTheme(Brightness.light),
    elevatedButtonTheme: _elevatedButtonTheme(),
    outlinedButtonTheme: _outlinedButtonTheme(),
    textButtonTheme: _textButtonTheme(),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: _appBarTheme(Brightness.light),
    snackBarTheme: _snackBarTheme(),
    cardTheme: _cardTheme(Brightness.light),
    chipTheme: _chipTheme(Brightness.light),
    floatingActionButtonTheme: _fabTheme(),
    dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), thickness: 1),
    bottomNavigationBarTheme: _bottomNavTheme(Brightness.light),
  );
}

ThemeData _buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      brightness: Brightness.dark,
      primary: const Color(0xFF66BB6A),
      onPrimary: const Color(0xFF003300),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF66BB6A),
    textTheme: _textTheme(Brightness.dark),
    inputDecorationTheme: _inputDecorationTheme(Brightness.dark),
    elevatedButtonTheme: _elevatedButtonTheme(),
    outlinedButtonTheme: _outlinedButtonTheme(),
    textButtonTheme: _textButtonTheme(),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: _appBarTheme(Brightness.dark),
    snackBarTheme: _snackBarTheme(),
    cardTheme: _cardTheme(Brightness.dark),
    chipTheme: _chipTheme(Brightness.dark),
    floatingActionButtonTheme: _fabTheme(),
    dividerTheme: const DividerThemeData(color: Color(0xFF2E2E2E), thickness: 1),
    bottomNavigationBarTheme: _bottomNavTheme(Brightness.dark),
  );
}

TextTheme _textTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return TextTheme(
    bodyMedium: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : _textPrimary),
    bodyLarge: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : _textPrimary),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _textPrimary),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : _textPrimary),
    labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
  );
}

InputDecorationTheme _inputDecorationTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    filled: true,
    fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD32F2F)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
    ),
    labelStyle: TextStyle(color: isDark ? Colors.white54 : _textSecondary),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme() {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      minimumSize: const Size(0, 52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
  );
}

OutlinedButtonThemeData _outlinedButtonTheme() {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryGreen,
      padding: const EdgeInsets.symmetric(vertical: 16),
      minimumSize: const Size(0, 52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: const BorderSide(color: _primaryGreen),
    ),
  );
}

TextButtonThemeData _textButtonTheme() {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primaryGreen,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}

AppBarTheme _appBarTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return AppBarTheme(
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    elevation: 0,
    centerTitle: false,
    foregroundColor: isDark ? Colors.white : _textPrimary,
    surfaceTintColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : _textPrimary,
    ),
  );
}

SnackBarThemeData _snackBarTheme() {
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentTextStyle: const TextStyle(fontSize: 15, color: Colors.white),
  );
}

CardThemeData _cardTheme(Brightness brightness) {
  return CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    color: brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
  );
}

ChipThemeData _chipTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ChipThemeData(
    selectedColor: const Color(0xFFE8F5E9),
    backgroundColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
    side: BorderSide(color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0)),
    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _textPrimary),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}

FloatingActionButtonThemeData _fabTheme() {
  return FloatingActionButtonThemeData(
    backgroundColor: _primaryGreen,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

BottomNavigationBarThemeData _bottomNavTheme(Brightness brightness) {
  return BottomNavigationBarThemeData(
    backgroundColor: brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
    selectedItemColor: _primaryGreen,
    unselectedItemColor: const Color(0xFFBDBDBD),
    type: BottomNavigationBarType.fixed,
    elevation: 8,
    selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
  );
}

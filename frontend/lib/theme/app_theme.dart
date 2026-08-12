import 'package:flutter/material.dart';

/// Definicje wyglądu aplikacji — jasny (domyślny) i ciemny motyw.
///
/// `backgroundColor`, `surfaceColor`, `textPrimary`, `textSecondary` są
/// gettterami (nie stałymi), bo ich wartość zależy od aktualnie wybranego
/// trybu — patrz [ThemeProvider]. Kolory marki (`primaryColor` i inne)
/// zostają stałymi, bo wyglądają dobrze w obu trybach.
class AppTheme {
  AppTheme._();

  /// Ustawiane przez [ThemeProvider] przy starcie aplikacji i przy każdej
  /// zmianie motywu. Statyczne pole (zamiast np. InheritedWidget) celowo —
  /// pozwala używać `AppTheme.textSecondary` itd. bezpośrednio w kodzie
  /// ekranów, tak jak wcześniej, bez przepisywania dziesiątek miejsc na
  /// `Theme.of(context)`.
  static bool _isDark = false;
  static bool get isDark => _isDark;
  static void setDark(bool value) => _isDark = value;

  // ── Kolory marki — takie same w obu trybach ─────────────────────
  static const Color primaryColor = Color(0xFF10B981); // Emerald Green
  static const Color secondaryColor = Color(0xFF8B5CF6); // Violet
  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444);

  // ── Paleta ciemna ────────────────────────────────────────────────
  static const Color _darkBackground = Color(0xFF0F0F1A);
  static const Color _darkSurface = Color(0xFF1A1B2E);
  static const Color _darkTextPrimary = Color(0xFFF8FAFC);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);

  // ── Paleta jasna (nowy domyślny wygląd aplikacji) ───────────────
  static const Color _lightBackground = Color(0xFFF7F8FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF16181D);
  static const Color _lightTextSecondary = Color(0xFF6B7280);

  static Color get backgroundColor => _isDark ? _darkBackground : _lightBackground;
  static Color get surfaceColor => _isDark ? _darkSurface : _lightSurface;
  static Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary => _isDark ? _darkTextSecondary : _lightTextSecondary;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDarkMode = brightness == Brightness.dark;
    final bg = isDarkMode ? _darkBackground : _lightBackground;
    final surface = isDarkMode ? _darkSurface : _lightSurface;
    final txtPrimary = isDarkMode ? _darkTextPrimary : _lightTextPrimary;
    final txtSecondary = isDarkMode ? _darkTextSecondary : _lightTextSecondary;

    final colorScheme = isDarkMode
        ? ColorScheme.dark(
            surface: surface,
            primary: primaryColor,
            secondary: secondaryColor,
            error: errorColor,
            onSurface: txtPrimary,
          )
        : ColorScheme.light(
            surface: surface,
            primary: primaryColor,
            secondary: secondaryColor,
            error: errorColor,
            onSurface: txtPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,

      // Typografia
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: txtPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: txtPrimary),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: txtPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: txtPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: txtPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: txtPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: txtSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtPrimary),
      ),

      // Kafelki i karty
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDarkMode ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Przyciski
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // Pola tekstowe (Inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: isDarkMode ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: isDarkMode ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: txtSecondary),
        floatingLabelStyle: const TextStyle(color: primaryColor),
        prefixIconColor: txtSecondary,
        suffixIconColor: txtSecondary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: txtPrimary),
        iconTheme: IconThemeData(color: txtPrimary),
      ),

      // Dolny pasek nawigacyjny
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryColor,
        unselectedItemColor: txtSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      dividerColor: isDarkMode ? Colors.white24 : Colors.black12,
      iconTheme: IconThemeData(color: txtSecondary),
    );
  }
}

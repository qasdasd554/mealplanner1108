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
  static const Color _darkSurfaceRaised = Color(0xFF24263D);
  static const Color _darkOutline = Color(0xFF526079);
  static const Color _darkTextPrimary = Color(0xFFF8FAFC);
  static const Color _darkTextSecondary = Color(0xFFB4C0D2);
  static const Color _darkPrimary = Color(0xFF34D399);
  static const Color _darkSecondary = Color(0xFFA78BFA);
  static const Color _darkAccent = Color(0xFFFBBF24);

  // ── Paleta jasna (nowy domyślny wygląd aplikacji) ───────────────
  static const Color _lightBackground = Color(0xFFF7F8FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF16181D);
  static const Color _lightTextSecondary = Color(0xFF6B7280);

  static Color get backgroundColor =>
      _isDark ? _darkBackground : _lightBackground;
  static Color get surfaceColor => _isDark ? _darkSurface : _lightSurface;
  static Color get textPrimary =>
      _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      _isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color get controlFillColor =>
      _isDark ? _darkSurfaceRaised : _lightSurface;
  static Color get outlineColor =>
      _isDark ? _darkOutline : const Color(0xFFD1D5DB);
  static Color get actionPrimaryColor => _isDark ? _darkPrimary : primaryColor;
  static Color get actionSecondaryColor =>
      _isDark ? _darkSecondary : secondaryColor;
  static Color get actionAccentColor => _isDark ? _darkAccent : accentColor;
  static Color get primaryTintColor =>
      _isDark ? _darkPrimary.withOpacity(0.18) : primaryColor.withOpacity(0.10);
  static Color get accentTintColor =>
      _isDark ? _darkAccent.withOpacity(0.18) : accentColor.withOpacity(0.10);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDarkMode = brightness == Brightness.dark;
    final bg = isDarkMode ? _darkBackground : _lightBackground;
    final surface = isDarkMode ? _darkSurface : _lightSurface;
    final txtPrimary = isDarkMode ? _darkTextPrimary : _lightTextPrimary;
    final txtSecondary = isDarkMode ? _darkTextSecondary : _lightTextSecondary;
    final interactivePrimary = isDarkMode ? _darkPrimary : primaryColor;
    final interactiveSecondary = isDarkMode ? _darkSecondary : secondaryColor;
    final interactiveAccent = isDarkMode ? _darkAccent : accentColor;
    final onPrimary = isDarkMode ? const Color(0xFF052E24) : Colors.white;
    final outline = isDarkMode ? _darkOutline : const Color(0xFFD1D5DB);
    final disabledBackground =
        isDarkMode ? const Color(0xFF293149) : const Color(0xFFE5E7EB);
    final disabledForeground =
        isDarkMode ? const Color(0xFF9AA8BD) : const Color(0xFF6B7280);

    final colorScheme =
        isDarkMode
            ? ColorScheme.dark(
              surface: surface,
              primary: interactivePrimary,
              onPrimary: onPrimary,
              secondary: interactiveSecondary,
              onSecondary: const Color(0xFF1E103F),
              error: errorColor,
              onError: Colors.white,
              onSurface: txtPrimary,
            )
            : ColorScheme.light(
              surface: surface,
              primary: interactivePrimary,
              onPrimary: onPrimary,
              secondary: interactiveSecondary,
              onSecondary: Colors.white,
              error: errorColor,
              onError: Colors.white,
              onSurface: txtPrimary,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,

      // Typografia
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: txtPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: txtPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: txtPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: txtPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: txtPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: txtPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: txtSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: txtPrimary,
        ),
      ),

      // Kafelki i karty
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDarkMode ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(
            color: isDarkMode ? outline.withOpacity(0.55) : Colors.transparent,
          ),
        ),
      ),

      // Przyciski
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: interactivePrimary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: disabledBackground,
          disabledForegroundColor: disabledForeground,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          side:
              isDarkMode
                  ? BorderSide(color: _darkPrimary.withOpacity(0.85), width: 1)
                  : BorderSide.none,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: interactivePrimary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: disabledBackground,
          disabledForegroundColor: disabledForeground,
          minimumSize: const Size.fromHeight(48),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: interactivePrimary,
          disabledForegroundColor: disabledForeground,
          backgroundColor:
              isDarkMode
                  ? interactivePrimary.withOpacity(0.08)
                  : Colors.transparent,
          side: BorderSide(
            color: interactivePrimary,
            width: isDarkMode ? 1.8 : 1.5,
          ),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: interactivePrimary,
          disabledForegroundColor: disabledForeground,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDarkMode ? txtPrimary : primaryColor,
          disabledForegroundColor: disabledForeground,
          minimumSize: const Size(44, 44),
          highlightColor: interactivePrimary.withOpacity(0.18),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: interactivePrimary,
        foregroundColor: onPrimary,
        elevation: isDarkMode ? 2 : 4,
        focusColor: interactiveAccent.withOpacity(0.22),
      ),

      chipTheme: ChipThemeData(
        backgroundColor:
            isDarkMode ? _darkSurfaceRaised : const Color(0xFFF3F4F6),
        selectedColor: interactivePrimary.withOpacity(isDarkMode ? 0.28 : 0.18),
        disabledColor: disabledBackground,
        labelStyle: TextStyle(color: txtPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
          color: txtPrimary,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: interactivePrimary,
        side: BorderSide(color: outline, width: isDarkMode ? 1.2 : 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // Pola tekstowe (Inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: outline, width: isDarkMode ? 1.2 : 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: outline, width: isDarkMode ? 1.2 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: interactivePrimary, width: 1.8),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: txtSecondary),
        floatingLabelStyle: TextStyle(color: interactivePrimary),
        prefixIconColor: txtSecondary,
        suffixIconColor: txtSecondary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: txtPrimary,
        ),
        iconTheme: IconThemeData(color: txtPrimary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDarkMode ? _darkSurfaceRaised : const Color(0xFF20242B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Dolny pasek nawigacyjny
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: interactivePrimary,
        unselectedItemColor: txtSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      dividerColor: isDarkMode ? Colors.white24 : Colors.black12,
      iconTheme: IconThemeData(color: txtSecondary),
      disabledColor: disabledForeground,
    );
  }
}

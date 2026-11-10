import 'package:flutter/material.dart';

/// VLXD Bay Hai - visual style only. No changes to business logic or data.
/// Blue = primary action, green = success, amber = attention, red = danger.
abstract final class VlxdPalette {
  static const primary = Color(0xFF0869DC);
  static const primaryDark = Color(0xFF094B9F);
  static const ink = Color(0xFF173253);
  static const secondary = Color(0xFF617793);
  static const background = Color(0xFFF4F7FC);
  static const border = Color(0xFFDCE5F0);
  static const success = Color(0xFF147B55);
  static const warning = Color(0xFFA85B00);
  static const danger = Color(0xFFC02D3A);
  static const white = Colors.white;
}

abstract final class VlxdUiTheme {
  static ThemeData get light {
    const radius = 11.0;
    const outline = BorderSide(color: VlxdPalette.border);
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: VlxdPalette.primary,
      primary: VlxdPalette.primary,
      onPrimary: Colors.white,
      surface: VlxdPalette.white,
      onSurface: VlxdPalette.ink,
      error: VlxdPalette.danger,
      brightness: Brightness.light,
    );
    final text = base.textTheme
        .apply(bodyColor: VlxdPalette.ink, displayColor: VlxdPalette.ink)
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: VlxdPalette.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: VlxdPalette.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: VlxdPalette.ink,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: VlxdPalette.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.35,
            color: VlxdPalette.ink,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: VlxdPalette.secondary,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: VlxdPalette.background,
      canvasColor: VlxdPalette.background,
      textTheme: text,
      visualDensity: VisualDensity.compact,
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: VlxdPalette.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: outline,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VlxdPalette.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: VlxdPalette.secondary, fontSize: 14),
        labelStyle: const TextStyle(color: VlxdPalette.secondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: outline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: outline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: VlxdPalette.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: VlxdPalette.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VlxdPalette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(40, 42),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VlxdPalette.primaryDark,
          side: outline,
          minimumSize: const Size(40, 41),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VlxdPalette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: VlxdPalette.primaryDark,
          minimumSize: const Size(40, 40),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VlxdPalette.white,
        selectedColor: const Color(0xFFE5F0FF),
        disabledColor: const Color(0xFFF0F3F7),
        side: outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: VlxdPalette.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      ),
      dividerTheme: const DividerThemeData(
        color: VlxdPalette.border,
        thickness: 1,
        space: 20,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F5FC)),
        headingTextStyle: const TextStyle(
          fontSize: 14,
          color: VlxdPalette.ink,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: const TextStyle(fontSize: 14, color: VlxdPalette.ink),
        dataRowMinHeight: 43,
        dataRowMaxHeight: 55,
        headingRowHeight: 43,
        dividerThickness: 0.8,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontSize: 21,
          color: VlxdPalette.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VlxdPalette.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VlxdPalette.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: VlxdPalette.primaryDark,
        textColor: VlxdPalette.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(9),
        thickness: const WidgetStatePropertyAll(7),
        thumbColor: const WidgetStatePropertyAll(Color(0xFFB3C5DA)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VlxdPalette.primary,
      ),
    );
  }
}

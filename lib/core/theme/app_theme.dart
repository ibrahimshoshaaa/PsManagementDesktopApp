import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const radius = BorderRadius.all(Radius.circular(12));
    const fieldBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.divider),
    );
    const actionShape = RoundedRectangleBorder(borderRadius: radius);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Color(0xFF112A25),
        primaryContainer: AppColors.sidebarSelected,
        onPrimaryContainer: AppColors.accent,
        secondary: Color(0xFFAAC8FF),
        secondaryContainer: AppColors.card2,
        onSecondaryContainer: AppColors.ink,
        surface: AppColors.sidebar,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        outline: Color(0xFF637891),
        outlineVariant: AppColors.divider,
        error: AppColors.red,
        surfaceTint: Colors.transparent,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.3),
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35),
        titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink),
        bodySmall: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.sidebar, elevation: 0, centerTitle: false),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.card,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.sidebar,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.divider),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        labelStyle: TextStyle(color: AppColors.muted),
        floatingLabelStyle: TextStyle(color: AppColors.accent),
        hintStyle: TextStyle(color: AppColors.textWhite38),
        prefixIconColor: AppColors.muted,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.red, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        shape: actionShape, minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        shape: actionShape, minimumSize: const Size(0, 44),
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        shape: actionShape, minimumSize: const Size(0, 40),
      )),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
        selectedColor: AppColors.accent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 350)),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card2,
        contentTextStyle: TextStyle(color: AppColors.ink),
        actionTextColor: AppColors.accent,
        shape: actionShape,
      ),
    );
  }
}

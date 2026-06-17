import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paleta Trazos ────────────────────────────────────────────────────────────
abstract final class AppColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C26);
  static const border = Color(0xFF2A2A38);

  static const accent = Color(0xFFFF4D6D); // rojo principal
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF39FF7A);
  static const gold = Color(0xFFFFB800);

  static const textPrimary = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF8888AA);
  static const textDisabled = Color(0xFF444460);

  // Gradientes
  static const gradientAccent = LinearGradient(
    colors: [Color(0xFFFF4D6D), Color(0xFFFF1744)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientCyan = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Colores de zona según propietario
  static const zoneFree = Color(0xFF2A2A38);
  static const zoneOwned = Color(0xFFFF4D6D);
  static const zoneClub = Color(0xFF00E5FF);
  static const zoneExpiring = Color(0xFFFFB800);
}

// ── TextStyles ────────────────────────────────────────────────────────────────
abstract final class AppTextStyles {
  static TextStyle _base({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static final displayLarge =
      _base(size: 32, weight: FontWeight.w700, height: 1.15);
  static final displayMedium =
      _base(size: 26, weight: FontWeight.w700, height: 1.2);
  static final headlineLarge =
      _base(size: 22, weight: FontWeight.w600, height: 1.25);
  static final headlineMedium =
      _base(size: 18, weight: FontWeight.w600, height: 1.3);
  static final titleLarge = _base(size: 16, weight: FontWeight.w600);
  static final titleMedium = _base(size: 15, weight: FontWeight.w500);
  static final bodyLarge =
      _base(size: 15, weight: FontWeight.w400, height: 1.5);
  static final bodyMedium =
      _base(size: 14, weight: FontWeight.w400, height: 1.5);
  static final labelLarge =
      _base(size: 13, weight: FontWeight.w600, letterSpacing: 0.5);
  static final labelMedium = _base(size: 12, weight: FontWeight.w500);
  static final caption =
      _base(size: 11, weight: FontWeight.w400, color: AppColors.textSecondary);

  // Variante acento
  static final statNumber = _base(
    size: 36,
    weight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: -1,
  );
  static final statLabel = _base(
    size: 11,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );
}

// ── ThemeData ─────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: AppColors.textPrimary,
    secondary: AppColors.cyan,
    onSecondary: AppColors.background,
    error: Color(0xFFCF6679),
    onError: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.dmSans().fontFamily,

    // AppBar sin elevación ni color propio
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),

    // Cards como superficies oscuras
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    // ElevatedButton = botón accent degradado
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
    ),

    // OutlinedButton = borde accent
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    // TextButton sin fondo
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    // InputDecoration uniforme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCF6679)),
      ),
      hintStyle:
          AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
      labelStyle:
          AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
    ),

    // BottomSheet oscuro
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      dragHandleColor: AppColors.border,
      showDragHandle: true,
    ),

    // Tabs sin indicador material clásico
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle:
          AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
      unselectedLabelStyle:
          AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
    ),

    // Chip oscuro
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: AppTextStyles.labelMedium,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    // FloatingActionButton accent
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textPrimary,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Divider sutil
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    useMaterial3: true,
  );
}

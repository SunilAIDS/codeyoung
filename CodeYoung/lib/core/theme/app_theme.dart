import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryDarkBlue = Color(0xFF1565C0);
  static const Color primaryLightBlue = Color(0xFF42A5F5);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color accentPink = Color(0xFFE91E63);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color accentCyan = Color(0xFF00BCD4);
  
  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color bgDarkSurface = Color(0xFF16213E);
  static const Color bgDarkCard = Color(0xFF1E1E2E);
  
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFE0E0E0);
  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryBlue, AppColors.primaryDarkBlue],
  );
  
  static const LinearGradient primaryLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryBlue, AppColors.primaryLightBlue],
  );
  
  static const LinearGradient welcome = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryBlue, AppColors.accentPurple],
  );
  
  static const LinearGradient success = LinearGradient(
    colors: [AppColors.accentGreen, Color(0xFF8BC34A)],
  );
  
  static const LinearGradient warning = LinearGradient(
    colors: [AppColors.accentOrange, Color(0xFFFFC107)],
  );
  
  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
  );

  // Premium banner / hero treatments used across the app.
  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFFC107)],
  );

  static const LinearGradient ocean = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B4DB), Color(0xFF0083B0), Color(0xFF005F9E)],
  );

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B09B), Color(0xFF11998E)],
  );

  static const LinearGradient grape = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
  );

  static const LinearGradient nightSky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F2937), Color(0xFF111827), Color(0xFF0B1220)],
  );

  /// Text-safe gradient for hero headlines on light backgrounds.
  static const LinearGradient headline = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1E88E5), Color(0xFF7B61FF)],
  );

  /// Picks a gradient from a name so banners can request one by key.
  static LinearGradient byName(String? name) {
    switch (name) {
      case 'sunset':
        return sunset;
      case 'ocean':
        return ocean;
      case 'mint':
        return mint;
      case 'grape':
        return grape;
      case 'gold':
        return gold;
      case 'night':
        return nightSky;
      case 'premium':
        return premium;
      case 'welcome':
        return welcome;
      default:
        return primary;
    }
  }
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      secondary: AppColors.accentOrange,
      tertiary: AppColors.accentGreen,
      surface: AppColors.bgWhite,
      onPrimary: AppColors.textOnPrimary,
      onSecondary: AppColors.textOnPrimary,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textOnPrimary,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AppColors.bgLight,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.bgWhite,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.bgWhite,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        side: const BorderSide(color: AppColors.primaryBlue, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgWhite,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
      selectedColor: AppColors.primaryBlue,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.primaryBlue,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textOnPrimary,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.primaryBlue, width: 1),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF323232),
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textOnPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textOnPrimary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textOnPrimary,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryLightBlue,
      brightness: Brightness.dark,
      primary: AppColors.primaryLightBlue,
      secondary: AppColors.accentOrange,
      tertiary: AppColors.accentGreen,
      surface: AppColors.bgDarkSurface,
      onPrimary: AppColors.textOnPrimary,
      onSecondary: AppColors.textOnPrimary,
      onSurface: AppColors.textOnDark,
      error: AppColors.error,
      onError: AppColors.textOnPrimary,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AppColors.bgDark,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.bgDarkSurface,
      foregroundColor: AppColors.textOnDark,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.bgDarkCard,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLightBlue,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLightBlue,
        side: const BorderSide(color: AppColors.primaryLightBlue, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgDarkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryLightBlue, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textSecondary,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnDark,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnDark,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textOnDark,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textOnDark,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textOnDark,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textOnDark,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.deepCharcoal,
    primaryColor: AppColors.zestyLime,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.zestyLime,
      surface: AppColors.surfaceDark,
      background: AppColors.deepCharcoal,
      onPrimary: AppColors.deepCharcoal,
      onSurface: AppColors.electricWhite,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: const TextStyle(
        color: AppColors.electricWhite,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.electricWhite,
      ),
    ),
    iconTheme: const IconThemeData(
      color: AppColors.electricWhite,
    ),
    // Define other component themes as needed
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kRed = Color(0xFFD90000);
const kBlack = Color(0xFF0A0A0A);
const kSurface = Color(0xFF161616);
const kCard = Color(0xFF1E1E1E);
const kBorder = Color(0xFF2A2A2A);
const kWhite = Color(0xFFEEEEEE);
const kGrey = Color(0xFF666666);

ThemeData buildAppTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: kBlack,
    colorScheme: const ColorScheme.dark(
      primary: kRed,
      secondary: kWhite,
      surface: kSurface,
      onPrimary: kWhite,
      onSurface: kWhite,
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: kBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBlack,
      foregroundColor: kWhite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.bebasNeue(
        fontSize: 26,
        color: kRed,
        letterSpacing: 3,
      ),
      iconTheme: const IconThemeData(color: kWhite),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kBlack,
      selectedItemColor: kRed,
      unselectedItemColor: kGrey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerColor: kBorder,
    textTheme: base.textTheme.copyWith(
      bodyLarge: const TextStyle(
        color: kWhite, fontSize: 15,
        fontFamilyFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', 'sans-serif'],
      ),
      bodyMedium: const TextStyle(
        color: kWhite, fontSize: 13,
        fontFamilyFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', 'sans-serif'],
      ),
      bodySmall: const TextStyle(
        color: kGrey, fontSize: 11,
        fontFamilyFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', 'sans-serif'],
      ),
      titleLarge: const TextStyle(
        color: kWhite, fontWeight: FontWeight.bold,
        fontFamilyFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', 'sans-serif'],
      ),
      titleMedium: const TextStyle(
        color: kWhite, fontWeight: FontWeight.bold,
        fontFamilyFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', 'sans-serif'],
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: kBorder),
        borderRadius: BorderRadius.zero,
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kBorder),
        borderRadius: BorderRadius.zero,
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kRed, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      labelStyle: const TextStyle(color: kGrey),
      hintStyle: const TextStyle(color: kGrey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kRed,
        foregroundColor: kWhite,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kRed,
        foregroundColor: kWhite,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: kBorder),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kRed,
      foregroundColor: kWhite,
      shape: CircleBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurface,
      contentTextStyle: TextStyle(color: kWhite),
    ),
  );
}

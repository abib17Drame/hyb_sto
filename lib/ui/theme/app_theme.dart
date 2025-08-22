import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Ce fichier centralise le design system de l'application (couleurs, polices, etc.)
// comme demandé dans les spécifications UX/UI.

class AppTheme {
  // Palette de couleurs définie dans les spécifications.
  // Utilisation de couleurs neutres avec un accent pour les actions.
  static const Color primaryColor = Color(0xFF0A7AFF); // Un bleu pour l'accentuation
  static const Color secondaryColor = Color(0xFF34C759); // Un vert pour les succès/confirmations
  static const Color backgroundColorLight = Color(0xFFF2F2F7);
  static const Color surfaceColorLight = Color(0xFFFFFFFF);
  static const Color textColorLight = Color(0xFF000000);
  static const Color secondaryTextColorLight = Color(0xFF8A8A8E);

  static const Color backgroundColorDark = Color(0xFF000000);
  static const Color surfaceColorDark = Color(0xFF1C1C1E);
  static const Color textColorDark = Color(0xFFFFFFFF);
  static const Color secondaryTextColorDark = Color(0xFF8D8D93);

  static const Color errorColor = Color(0xFFFF3B30);


  // Thème clair
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColorLight,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColorLight,
      background: backgroundColorLight,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textColorLight,
      onBackground: textColorLight,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColorLight,
      elevation: 0,
      iconTheme: const IconThemeData(color: primaryColor),
      titleTextStyle: GoogleFonts.lato(
        color: textColorLight,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: GoogleFonts.latoTextTheme().apply(
      bodyColor: textColorLight,
      displayColor: textColorLight,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColorLight,
      selectedItemColor: primaryColor,
      unselectedItemColor: secondaryTextColorLight,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Thème sombre
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColorDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColorDark,
      background: backgroundColorDark,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textColorDark,
      onBackground: textColorDark,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColorDark,
      elevation: 0,
      iconTheme: const IconThemeData(color: primaryColor),
      titleTextStyle: GoogleFonts.lato(
        color: textColorDark,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: GoogleFonts.latoTextTheme().apply(
      bodyColor: textColorDark,
      displayColor: textColorDark,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColorDark,
      selectedItemColor: primaryColor,
      unselectedItemColor: secondaryTextColorDark,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontService {
  // Font family constants
  static const String defaultFont = 'Roboto';
  static const String openDyslexicFont = 'OpenDyslexic';
  static const String lexendFont = 'ComicSans'; // Still using 'ComicSans' as the key for backward compatibility
  
  // Font size constants
  static const double smallFontSize = 14.0;
  static const double mediumFontSize = 16.0;
  static const double largeFontSize = 18.0;
  static const double extraLargeFontSize = 20.0;
  
  // Preference keys
  static const String fontFamilyKey = 'font_family';
  static const String fontSizeKey = 'font_size';
  
  // List of available fonts
  static List<String> get availableFonts => [
    defaultFont,
    openDyslexicFont,
    lexendFont,
  ];
  
  // Get font display names
  static String getFontDisplayName(String fontFamily) {
    switch (fontFamily) {
      case openDyslexicFont:
        return 'OpenDyslexic';
      case lexendFont:
        return 'Lexend';
      default:
        return 'Default';
    }
  }
  
  // Get the current font family from preferences
  static Future<String> getCurrentFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(fontFamilyKey) ?? defaultFont;
  }
  
  // Save the font family preference
  static Future<bool> saveFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(fontFamilyKey, fontFamily);
  }
  
  // Get the current font size from preferences
  static Future<double> getCurrentFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(fontSizeKey) ?? mediumFontSize;
  }
  
  // Save the font size preference
  static Future<bool> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setDouble(fontSizeKey, fontSize);
  }
  
  // Get a TextStyle with the specified font family and size
  static TextStyle getTextStyle({
    required String fontFamily,
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
    Color color = Colors.black,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpay/config/counties.dart';
import 'package:smartpay/model/county.dart' show County;

class CountyThemeProvider extends ChangeNotifier {
  late County _county;
  late ThemeData _theme;
  final StreamController<County> _countyController =
      StreamController<County>.broadcast();

  CountyThemeProvider(String countyCode) {
    try {
      _county = CountyConfig.getCounty(countyCode);
      _theme = _buildTheme();
    } catch (e) {
      // Fallback to a default county if the provided one doesn't exist
      _county = CountyConfig.getCounty('001'); // Default to Nairobi
      _theme = _buildTheme();
    }
  }

  ThemeData get theme => _theme;
  County get county => _county;

  Stream<County>? get countyStream => _countyController.stream;

  // Safe color getters with fallback values
  Color get primaryColor {
    try {
      final colorString = _county.theme['primaryColor'] ?? '#2196F3';
      return _parseColor(colorString);
    } catch (e) {
      return Colors.blue; // Fallback color
    }
  }

  Color get secondaryColor {
    try {
      final colorString = _county.theme['secondaryColor'] ?? '#4CAF50';
      return _parseColor(colorString);
    } catch (e) {
      return Colors.green; // Fallback color
    }
  }

  Color get accentColor {
    try {
      final colorString = _county.theme['accentColor'] ?? '#FF9800';
      return _parseColor(colorString);
    } catch (e) {
      return Colors.orange; // Fallback color
    }
  }

  // Helper method to parse color string safely
  Color _parseColor(String colorString) {
    try {
      // Ensure the string has the correct format
      String hex = colorString;

      // Remove # if present
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }

      // Add alpha if missing
      if (hex.length == 6) {
        hex = 'FF$hex'; // Full opacity
      }

      // Parse to integer
      final colorInt = int.parse(hex, radix: 16);
      return Color(colorInt);
    } catch (e) {
      print('Error parsing color $colorString: $e');
      return Colors.blue; // Fallback to blue
    }
  }

  LinearGradient get primaryGradient => LinearGradient(
        colors: [
          primaryColor,
          secondaryColor,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
      ),
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      useMaterial3: true,
    );
  }

  // MaterialColor generator (fixed version)
  MaterialColor _generateMaterialColor(Color color) {
    final Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    // Create shades from 50 to 900
    swatch[50] = Color.fromRGBO(r, g, b, 0.1);
    swatch[100] = Color.fromRGBO(r, g, b, 0.2);
    swatch[200] = Color.fromRGBO(r, g, b, 0.3);
    swatch[300] = Color.fromRGBO(r, g, b, 0.4);
    swatch[400] = Color.fromRGBO(r, g, b, 0.5);
    swatch[500] = Color.fromRGBO(r, g, b, 0.6);
    swatch[600] = Color.fromRGBO(r, g, b, 0.7);
    swatch[700] = Color.fromRGBO(r, g, b, 0.8);
    swatch[800] = Color.fromRGBO(r, g, b, 0.9);
    swatch[900] = Color.fromRGBO(r, g, b, 1.0);

    return MaterialColor(color.value, swatch);
  }

  Future<void> updateCounty(String countyCode) async {
    try {
      final newCounty = CountyConfig.getCounty(countyCode);
      _county = newCounty;
      _theme = _buildTheme();

      // Add to stream for listeners
      _countyController.add(newCounty);

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_county', countyCode);

      notifyListeners();
      print('🎯 Theme provider updated to: ${newCounty.name}');
    } catch (e) {
      print('❌ Error updating county theme: $e');
      // Keep current county on error
    }
  }

  @override
  void dispose() {
    _countyController.close();
    super.dispose();
  }
}

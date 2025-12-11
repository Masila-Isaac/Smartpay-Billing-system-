// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Save login state
  static Future<void> setLoggedIn(bool value, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    }
  }

  // Get stored user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Logout user - UPDATED to include Firebase Auth
  static Future<void> logout() async {
    try {
      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);

      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      throw Exception('Logout failed: $e');
    }
  }
}

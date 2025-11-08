import 'dart:convert';
import 'package:http/http.dart' as http;

class MpesaService {
  static const String baseUrlEmulator = "http://10.0.2.2:5000";
  static const String baseUrlPhone = "http://10.10.13.194:5000";

  static String get baseUrl {
    // return baseUrlEmulator; // For emulator
    return baseUrlPhone; // For real phone
  }

  static Future<String?> initiatePayment({
    required String phone,
    required double amount,
    required String accountRef,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/mpesa/stkpush"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "phoneNumber": phone,
              "amount": amount,
              "accountRef": accountRef,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return data["CustomerMessage"] ?? "STK Push initiated successfully";
        } else {
          throw Exception(data["error"] ?? "STK Push failed");
        }
      } else {
        throw Exception(data["error"] ?? "HTTP ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }
}

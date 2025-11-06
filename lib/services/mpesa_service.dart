import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class MpesaService {
  static Future<String?> initiatePayment({
    required String phone,
    required double amount,
    required String accountRef,
  }) async {
    // ✅ Use correct backend base URL based on environment
    String backendUrl;

    if (Platform.isAndroid) {
      // For Android emulator → use 10.0.2.2
      backendUrl = "http://10.0.2.2:5000/mpesa/stkpush";
    } else if (Platform.isIOS) {
      // For iOS simulator
      backendUrl = "http://localhost:5000/mpesa/stkpush";
    } else {
      // For Flutter Web or physical device → use your computer's local IP
      // e.g., replace 192.168.x.x with your PC IP from `ipconfig`
      backendUrl = "http://192.168.0.105:5000/mpesa/stkpush"; // <-- CHANGE THIS
    }

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'amount': amount,
          'accountRef': accountRef,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ResponseDescription'] ?? "STK Push initiated successfully";
      } else {
        throw Exception("Failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      throw Exception("Connection error: $e");
    }
  }
}

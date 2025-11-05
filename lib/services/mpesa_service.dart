import 'package:http/http.dart' as http;
import 'dart:convert';

class MpesaService {
  static Future<String?> initiatePayment({
    required String phone,
    required double amount,
    required String accountRef,
  }) async {
    // For local testing, use 10.0.2.2 for Android emulator
    // If using real device, use your PC’s IP (e.g. http://192.168.1.10:5000)
    const String backendUrl = "http://10.0.2.2:5000/mpesa/stkpush";

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
      return data['ResponseDescription'] ?? "STK Push initiated";
    } else {
      throw Exception("Failed: ${response.statusCode} - ${response.body}");
    }
  }
}

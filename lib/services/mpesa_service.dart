import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class MpesaService {
  // ✅ Change this to your laptop's IP or ngrok URL
  static const String _baseUrl =
      'http://10.10.75.177:5000'; //change every time you have to run for you own good
  static const String _callbackUrl = "https://abcd1234.ngrok.io/mpesa/callback";

  // For Android emulator use 10.0.2.2, for iOS simulator 127.0.0.1

  // static const String _baseUrl = 'http://10.0.2.2:5000';

  /// Initiates M-Pesa STK Push payment
  static Future<String?> initiatePayment({
    required String phone,
    required double amount,
    required String accountRef,
  }) async {
    try {
      print('🔄 Initiating payment to: $_baseUrl/mpesa/stkpush');
      print('📱 Phone: $phone, Amount: $amount, Account: $accountRef');

      // POST request to your Node.js server
      final response = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/stkpush'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'phoneNumber': phone,
              'amount': amount,
              'accountRef': accountRef,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          // Save the transaction to Firestore as Pending
          await savePaymentToFirestore(
            phone: phone,
            amount: amount,
            accountRef: accountRef,
            status: 'Pending',
            transactionId:
                data['CheckoutRequestID'] ?? '', // optional if returned
          );

          return data['CustomerMessage'] ?? 'Payment initiated successfully';
        } else {
          throw Exception(data['error'] ?? 'Payment failed');
        }
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'HTTP error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('❌ HTTP Client Exception: $e');
      throw Exception(
          'Network error: Cannot connect to server. Please check if server is running.');
    } on FormatException catch (e) {
      print('❌ JSON Format Exception: $e');
      throw Exception('Invalid server response');
    } on Exception catch (e) {
      print('❌ General Exception: $e');
      rethrow;
    }
  }

  /// Saves the payment transaction to Firestore
  static Future<void> savePaymentToFirestore({
    required String phone,
    required double amount,
    required String accountRef,
    required String status,
    String? transactionId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('payments').add({
        'phone': phone,
        'amount': amount,
        'accountRef': accountRef,
        'status': status, // Pending/Success/Failed
        'transactionId': transactionId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Payment saved to Firestore with status: $status');
    } catch (e) {
      print('❌ Error saving payment: $e');
    }
  }

  /// Test connection to the server
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/test'),
          )
          .timeout(const Duration(seconds: 10));

      print('🔗 Server test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Server connection test failed: $e');
      return false;
    }
  }
}

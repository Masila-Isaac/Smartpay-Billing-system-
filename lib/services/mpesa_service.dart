import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/payment_model.dart';
import '../model/water_usage_model.dart';

class MpesaService {
  // Node.js backend URL - Update this with your actual server IP
  static const String _baseUrl = 'http://192.168.100.24:5000';

  static String get baseUrl => _baseUrl;

  /// Test Backend Connection
  static Future<bool> testConnection() async {
    try {
      print('🔗 Testing connection to: $baseUrl');

      // Try multiple endpoints
      final endpoints = ['/test', '/', '/health'];

      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          print('🔗 $endpoint status: ${response.statusCode}');
          print('🔗 $endpoint response: ${response.body}');

          if (response.statusCode == 200) {
            print('✅ Server connection successful via $endpoint');
            return true;
          }
        } catch (e) {
          print('❌ $endpoint failed: $e');
        }
      }

      return false;
    } catch (e) {
      print('❌ All connection attempts failed: $e');
      return false;
    }
  }

  /// Initiates M-Pesa STK Push Payment - Better error handling
  static Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
  }) async {
    try {
      print('🔄 Initiating payment to: $baseUrl/mpesa/stkpush');
      print('📱 Payment Details:');
      print('   User ID: $userId');
      print('   Phone: $phone');
      print('   Amount: $amount KES');
      print('   Meter: $meterNumber');

      // Format phone number (ensure it starts with 254)
      String formattedPhone = formatPhoneNumber(phone);

      final response = await http
          .post(
            Uri.parse('$baseUrl/mpesa/stkpush'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'userId': userId,
              'phoneNumber': formattedPhone,
              'amount': amount,
              'meterNumber': meterNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 HTTP Status Code: ${response.statusCode}');
      print('📡 Raw Response: ${response.body}');

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        print('❌ JSON Decode Error: $e');
        throw Exception("Invalid server response format");
      }

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          // Save payment to Firestore
          await savePaymentToFirestore(
            userId: userId,
            phone: formattedPhone,
            amount: amount,
            meterNumber: meterNumber,
            status: 'Pending',
            transactionId: data['CheckoutRequestID']?.toString() ?? '',
            reference: data['MerchantRequestID']?.toString() ?? '',
          );

          return {
            'success': true,
            'message':
                data['CustomerMessage'] ?? 'Payment initiated successfully',
            'reference': data['MerchantRequestID']?.toString() ?? 'N/A',
            'checkoutRequestId': data['CheckoutRequestID']?.toString() ?? '',
            'status': 'pending'
          };
        } else {
          String errorMessage =
              data['error'] ?? data['message'] ?? 'Payment request failed';
          print('❌ Payment failed: $errorMessage');
          throw Exception(errorMessage);
        }
      } else {
        String errorMessage =
            'Server error: ${response.statusCode} - ${data['error'] ?? 'Unknown error'}';
        print('❌ HTTP Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Payment Initiation Error: $e');

      // Save failed payment to Firestore for record keeping
      try {
        await savePaymentToFirestore(
          userId: userId,
          phone: phone,
          amount: amount,
          meterNumber: meterNumber,
          status: 'Failed',
          transactionId: '',
          reference: 'FAILED_${DateTime.now().millisecondsSinceEpoch}',
          error: e.toString(),
        );
      } catch (firestoreError) {
        print('❌ Failed to save failed payment: $firestoreError');
      }

      rethrow;
    }
  }

  /// Format phone number to MPesa format (254...)
  static String formatPhoneNumber(String phone) {
    // Remove any spaces or special characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Convert to 254 format
    if (cleaned.startsWith('0')) {
      return '254${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+254')) {
      return cleaned.substring(1);
    } else if (cleaned.startsWith('254')) {
      return cleaned;
    } else {
      return '254$cleaned';
    }
  }

  /// Saves Payment to Firestore using Payment Model
  static Future<void> savePaymentToFirestore({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required String status,
    required String transactionId,
    required String reference,
    String? error,
  }) async {
    try {
      final payment = Payment(
        id: '',
        userId: userId,
        phone: phone,
        amount: amount,
        meterNumber: meterNumber,
        status: status,
        transactionId: transactionId,
        timestamp: DateTime.now(),
        litresPurchased: calculateUnits(amount),
        processed: false,
        reference: reference,
        error: error,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('payments')
          .add(payment.toMap());

      print('✅ Payment saved to Firestore with ID: ${docRef.id}');
    } catch (e) {
      print('❌ Firestore Save Error: $e');
      rethrow;
    }
  }

  /// Calculate units based on amount (example: 1 unit = KES 50)
  static double calculateUnits(double amount) {
    const ratePerUnit = 50.0; // Adjust this rate as needed
    return amount / ratePerUnit;
  }

  /// Check Payment Status
  static Future<Map<String, dynamic>> checkPaymentStatus(
      String checkoutRequestId) async {
    try {
      print('🔄 Checking payment status for: $checkoutRequestId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/mpesa/query'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'CheckoutRequestID': checkoutRequestId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print(
          '📡 Status check response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to check payment status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Payment Status Check Error: $e');
      rethrow;
    }
  }

  /// Get Water Status by Meter Number
  static Future<Map<String, dynamic>> getWaterStatus(String meterNumber) async {
    try {
      print('🔄 Getting water status for: $meterNumber');

      final response = await http.get(
        Uri.parse('$baseUrl/api/water-status/$meterNumber'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get water status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Water Status Fetch Error: $e');
      rethrow;
    }
  }

  /// Get Water Usage by Meter Number
  static Future<WaterUsage?> getWaterUsage(String meterNumber) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('waterUsage')
          .doc(meterNumber)
          .get();

      if (doc.exists) {
        return WaterUsage.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Water Usage Fetch Error: $e');
      return null;
    }
  }

  /// Get Payment History
  static Future<List<Payment>> getPaymentHistory(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Payment History Error: $e');
      return [];
    }
  }

  /// Real-Time Water Usage Stream
  static Stream<WaterUsage?> getWaterUsageStream(String meterNumber) {
    return FirebaseFirestore.instance
        .collection('waterUsage')
        .doc(meterNumber)
        .snapshots()
        .map((doc) => doc.exists ? WaterUsage.fromFirestore(doc) : null);
  }

  /// Real-Time Payment History Stream
  static Stream<List<Payment>> getPaymentHistoryStream(String userId) {
    return FirebaseFirestore.instance
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Payment.fromFirestore(doc))
            .toList());
  }

  /// Update Payment Status
  static Future<void> updatePaymentStatus({
    required String transactionId,
    required String status,
    required String? mpesaReceiptNumber,
  }) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        await doc.reference.update({
          'status': status,
          'mpesaReceiptNumber': mpesaReceiptNumber,
          'processed': status == 'Completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Payment status updated to: $status');
      }
    } catch (e) {
      print('❌ Update Payment Status Error: $e');
      rethrow;
    }
  }

  /// Get server info
  static Future<Map<String, dynamic>> getServerInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get server info');
      }
    } catch (e) {
      print('❌ Server Info Error: $e');
      rethrow;
    }
  }
}

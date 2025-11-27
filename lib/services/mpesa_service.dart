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
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('🔗 Server test status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Server connection failed: $e');
      return false;
    }
  }

  /// Initiates M-Pesa STK Push Payment
  static Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
  }) async {
    try {
      print('🔄 Initiating payment to: $baseUrl/mpesa/stkpush');
      print(
          '📱 User: $userId, Phone: $phone, Amount: $amount, Meter: $meterNumber');

      final response = await http
          .post(
            Uri.parse('$baseUrl/mpesa/stkpush'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'userId': userId,
              'phoneNumber': phone,
              'amount': amount,
              'meterNumber': meterNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Invalid server response format");
      }

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          // Save payment to Firestore
          await savePaymentToFirestore(
            userId: userId,
            phone: phone,
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
          throw Exception(
              data['error'] ?? data['message'] ?? 'Payment request failed');
        }
      } else {
        throw Exception(
            'Server error: ${response.statusCode} - ${data['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Payment Error: $e');

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
        );
      } catch (firestoreError) {
        print('❌ Failed to save failed payment: $firestoreError');
      }

      rethrow;
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
        unitsPurchased: calculateUnits(amount),
        processed: false,
        reference: reference,
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

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to check payment status');
      }
    } catch (e) {
      print('❌ Payment Status Check Error: $e');
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
}

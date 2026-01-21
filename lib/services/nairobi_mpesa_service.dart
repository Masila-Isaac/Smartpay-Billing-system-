import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart';
import 'package:smartpay/services/county_payment_factory.dart';

class NairobiMpesaService implements CountyPaymentService {
  // Update these to point to your backend server
  final String _baseUrl =
      'https://smartpay-billing.onrender.com'; // Your Render URL
  final String _paybillNumber = '174379'; // M-Pesa test paybill

  @override
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhone(phone);

      // Calculate litres based on Nairobi water rate
      final litres = county.calculateLitres(amount);

      // Generate transaction reference
      final transactionRef =
          'NAI${DateTime.now().millisecondsSinceEpoch}${meterNumber.substring(meterNumber.length - 4)}';

      // Call YOUR BACKEND SERVER instead of direct M-Pesa API
      final response = await http.post(
        Uri.parse('$_baseUrl/mpesa/stkpush'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phoneNumber': formattedPhone,
          'amount': amount,
          'meterNumber': meterNumber,
          'userId': userId,
          'countyCode': county.code,
          'countyName': county.name,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Save transaction to Firestore
          await _saveTransaction(
            userId: userId,
            meterNumber: meterNumber,
            amount: amount,
            litres: litres,
            phone: formattedPhone,
            transactionRef: transactionRef,
            county: county,
            mpesaResponse: data,
            checkoutRequestId: data['CheckoutRequestID'],
          );

          return {
            'status': 'pending',
            'reference': transactionRef,
            'mpesa_ref': data['CheckoutRequestID'],
            'merchant_ref': data['MerchantRequestID'],
            'message':
                data['message'] ?? 'M-Pesa STK Push sent to $formattedPhone',
            'litres': litres,
            'county': county.name,
            'water_rate': county.waterRate,
            'phone': formattedPhone,
            'note': data['note'] ?? 'Check your phone for payment prompt',
          };
        } else {
          throw Exception(data['error'] ?? 'Payment initiation failed');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['error'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Nairobi payment error: $e');
      throw Exception('Nairobi payment error: $e');
    }
  }

  Future<void> _saveTransaction({
    required String userId,
    required String meterNumber,
    required double amount,
    required double litres,
    required String phone,
    required String transactionRef,
    required County county,
    required Map<String, dynamic> mpesaResponse,
    required String checkoutRequestId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('transactions').doc(transactionRef).set({
      'transaction_id': transactionRef,
      'user_id': userId,
      'meter_number': meterNumber,
      'county_code': county.code,
      'county_name': county.name,
      'amount': amount,
      'litres': litres,
      'water_rate': county.waterRate,
      'phone': phone,
      'payment_method': 'mpesa',
      'payment_gateway': 'Daraja API',
      'paybill_number': _paybillNumber,
      'status': 'pending',
      'mpesa_checkout_id': checkoutRequestId,
      'mpesa_merchant_id': mpesaResponse['MerchantRequestID'],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'metadata': {
        'water_provider': county.waterProvider,
        'customer_care': county.customerCare,
        'api_response': mpesaResponse,
      },
    });

    // Also save to user's transaction history
    await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add({
      'transaction_id': transactionRef,
      'type': 'water_purchase',
      'amount': amount,
      'litres': litres,
      'county': county.name,
      'status': 'pending',
      'mpesa_ref': checkoutRequestId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Connection test error: $e');
      return false;
    }
  }

  // Check payment status from backend
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/payment/$transactionId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check payment status');
      }
    } catch (e) {
      throw Exception('Status check error: $e');
    }
  }

  @override
  bool isValidPhone(String phone) {
    // Kenya phone validation (2547XXXXXXXX or 07XXXXXXXX)
    final regex = RegExp(r'^(254|0)[7-9][0-9]{8}$');
    return regex.hasMatch(phone.replaceAll(RegExp(r'\s+'), ''));
  }

  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return phone;
    } else if (phone.startsWith('7') && phone.length == 9) {
      return '254$phone';
    } else {
      return phone;
    }
  }

  @override
  String getPaybillNumber() => _paybillNumber;

  @override
  String getTillNumber() => '';

  @override
  String getAccountPrefix() => 'NAIROBIWATER';
}

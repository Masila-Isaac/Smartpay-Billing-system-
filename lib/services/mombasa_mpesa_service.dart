import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart';
import 'package:smartpay/services/county_payment_factory.dart';

class MombasaMpesaService implements CountyPaymentService {
  final String _baseUrl = 'https://smartpay-billing.onrender.com';
  final String _paybillNumber =
      '174379'; // This should likely be Mombasa-specific
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  }) async {
    try {
      // Format phone for Mombasa
      final formattedPhone = _formatMombasaPhone(phone);

      // Validate phone number
      if (!isValidPhone(formattedPhone)) {
        throw Exception('Invalid Mombasa phone number format');
      }

      // Calculate litres based on Mombasa water rate
      final litres = county.calculateLitres(amount);

      // Generate transaction reference
      final transactionRef =
          'MOM${DateTime.now().millisecondsSinceEpoch}${meterNumber.substring(meterNumber.length - 4)}';

      // Generate password for M-Pesa API
      final password = _generatePassword(county);

      // Call Mombasa County M-Pesa API
      final response = await http.post(
        Uri.parse('$_baseUrl/mpesa/stkpush'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'BusinessShortCode': _paybillNumber,
          'Password': password,
          'Timestamp': _generateTimestamp(),
          'TransactionType': 'CustomerPayBillOnline',
          'Amount': amount,
          'PartyA': formattedPhone,
          'PartyB': _paybillNumber,
          'PhoneNumber': formattedPhone,
          'CallBackURL': _getCallbackUrl(),
          'AccountReference': _getAccountReference(meterNumber),
          'TransactionDesc': 'Mombasa Water Payment',
          'CountyMetadata': {
            'county_code': county.code,
            'water_provider': county.waterProvider,
            'water_rate': county.waterRate,
            'litres_purchased': litres,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if M-Pesa API returned success
        if (data['ResponseCode'] != '0') {
          throw Exception('M-Pesa API error: ${data['ResponseDescription']}');
        }

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
        );

        return {
          'status': 'pending', // M-Pesa STK Push is pending user confirmation
          'success': true,
          'reference': transactionRef,
          'mpesa_ref': data['CheckoutRequestID'],
          'message': 'M-Pesa STK Push sent to $formattedPhone',
          'litres': litres,
          'county': county.name,
          'water_rate': county.waterRate,
        };
      } else {
        throw Exception(
            'Mombasa M-Pesa API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Mombasa payment error: $e');
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
  }) async {
    final firestore = FirebaseFirestore.instance;

    final transactionData = {
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
      'payment_gateway': county.paymentGateway,
      'paybill_number': county.paybillNumber ?? _paybillNumber,
      'status': 'pending',
      'mpesa_checkout_id': mpesaResponse['CheckoutRequestID'],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'metadata': {
        'water_provider': county.waterProvider,
        'customer_care': county.customerCare,
        'api_response': mpesaResponse,
      },
    };

    // Save to main transactions collection
    await firestore
        .collection('transactions')
        .doc(transactionRef)
        .set(transactionData);

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
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _generatePassword(County county) {
    // M-Pesa STK Push password generation format: base64(BusinessShortCode + Passkey + Timestamp)
    final timestamp = _generateTimestamp();
    final passkey = county.passkey; // You need to get this from County model
    final data = '${county.paybillNumber ?? _paybillNumber}$passkey$timestamp';
    return base64.encode(utf8.encode(data));
  }

  String _generateTimestamp() {
    // Format: YYYYMMDDHHMMSS
    final now = DateTime.now().toUtc();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  String _getCallbackUrl() {
    // This should be your callback URL for M-Pesa to send payment confirmation
    // Update this with your actual backend URL
    return 'https://smartpay-billing.onrender.com/api/mpesa-callback';
    // Or if you have a different callback endpoint:
    // return '$_baseUrl/mpesa/callback';
  }

  String _getAccountReference(String meterNumber) {
    return 'MOMBASAWATER${meterNumber.substring(meterNumber.length - 6)}';
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

  @override
  bool isValidPhone(String phone) {
    // Mombasa uses same Kenyan phone format
    final regex = RegExp(r'^(254|0)[7-9][0-9]{8}$');
    return regex.hasMatch(phone.replaceAll(RegExp(r'\s+'), ''));
  }

  String _formatMombasaPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return phone;
    } else if (phone.length == 9 && phone.startsWith('7')) {
      return '254$phone';
    } else {
      throw Exception('Invalid phone number format for Mombasa');
    }
  }

  @override
  String getPaybillNumber() => _paybillNumber;

  @override
  String getTillNumber() => ''; // Mombasa uses paybill, not till number

  @override
  String getAccountPrefix() => 'MOMBASAWATER';

  // Optional: Add method to check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(
      String checkoutRequestId, County county) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mpesa/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'BusinessShortCode': _paybillNumber,
          'Password': _generatePassword(county),
          'Timestamp': _generateTimestamp(),
          'CheckoutRequestID': checkoutRequestId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to query payment status');
    } catch (e) {
      throw Exception('Payment status check error: $e');
    }
  }
}

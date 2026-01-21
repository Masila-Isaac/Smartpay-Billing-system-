import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart';
import 'package:smartpay/services/county_payment_factory.dart';

class MombasaMpesaService implements CountyPaymentService {
  final String _apiKey = 'YOUR_NAIROBI_MPESA_API_KEY';
  final String _apiSecret = 'YOUR_NAIROBI_MPESA_API_SECRET';
  final String _paybillNumber = '123456';
  final String _callbackUrl = 'https://api.smartpay.co.ke/callbacks/nairobi';

  @override
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  }) async {
    try {
      // Format phone for Mombasa (remove leading 0, add 254)
      final formattedPhone = _formatMombasaPhone(phone);

      // Calculate litres based on Mombasa water rate
      final litres = county.calculateLitres(amount);

      // Generate transaction reference
      final transactionRef =
          'MOM${DateTime.now().millisecondsSinceEpoch}${meterNumber.substring(meterNumber.length - 4)}';

      // Call Mombasa County M-Pesa API
      final response = await http.post(
        Uri.parse('https://api.mombasa.go.ke/mpesa/v1/stkpush'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'X-County': 'Mombasa',
        },
        body: jsonEncode({
          'BusinessShortCode': _paybillNumber,
          'Password': _generatePassword(county),
          'Timestamp': DateTime.now().toUtc().toIso8601String(),
          'TransactionType': 'CustomerPayBillOnline',
          'Amount': amount,
          'PartyA': formattedPhone,
          'PartyB': _paybillNumber,
          'PhoneNumber': formattedPhone,
          'CallBackURL': _callbackUrl,
          'AccountReference': 'MOMBASAWATER$meterNumber',
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
          'status': data['ResponseCode'] == '0' ? 'pending' : 'failed',
          'reference': transactionRef,
          'mpesa_ref': data['CheckoutRequestID'],
          'message': 'M-Pesa STK Push sent to $formattedPhone',
          'litres': litres,
          'county': county.name,
          'water_rate': county.waterRate,
        };
      } else {
        throw Exception('Mombasa M-Pesa API error: ${response.statusCode}');
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
      'payment_gateway': county.paymentGateway,
      'paybill_number': county.paybillNumber,
      'status': 'pending',
      'mpesa_checkout_id': mpesaResponse['CheckoutRequestID'],
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
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _generatePassword(dynamic county) {
    final timestamp = DateTime.now().toUtc();
    final formattedTimestamp = timestamp
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.', '');

    final password = base64.encode(
      utf8.encode('$_paybillNumber${county.paybillNumber}$formattedTimestamp'),
    );

    return password;
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.nairobi.go.ke/mpesa/v1/status'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'X-County': 'Nairobi',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  bool isValidPhone(String phone) {
    // Nairobi phone validation (2547XXXXXXXX or 07XXXXXXXX)
    final regex = RegExp(r'^(254|0)[7-9][0-9]{8}$');
    return regex.hasMatch(phone.replaceAll(RegExp(r'\s+'), ''));
  }

  String _formatKisPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return phone;
    } else {
      return '2547${phone.substring(phone.length - 9)}';
    }
  }

  String _formatNairobiPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return phone;
    } else {
      return '2547${phone.substring(phone.length - 9)}';
    }
  }

  String _formatMombasaPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return phone;
    } else {
      return '2547${phone.substring(phone.length - 9)}';
    }
  }

  @override
  String getPaybillNumber() => _paybillNumber;

  @override
  String getTillNumber() => '';

  @override
  String getAccountPrefix() => 'NAIROBIWATER';
}

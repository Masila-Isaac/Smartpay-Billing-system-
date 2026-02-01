import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart';
import 'package:smartpay/services/county_payment_factory.dart';

class NairobiMpesaService implements CountyPaymentService {
  final String _baseUrl = 'https://smartpay-billing.onrender.com';
  final String _paybillNumber = '174379';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _statusCheckTimers = {};

  @override
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  }) async {
    try {
      final formattedPhone = _formatPhone(phone);
      final litres = county.calculateLitres(amount);
      final transactionRef =
          'NAI${DateTime.now().millisecondsSinceEpoch}${meterNumber.substring(meterNumber.length - 4)}';

      // Fetch user details
      final userDetails = await _getUserDetails(userId);
      final fullName = userDetails['name'] ?? 'Unknown';

      debugPrint('🔵 Sending STK Push to: $formattedPhone');
      debugPrint('🔵 Amount: $amount');
      debugPrint('🔵 Transaction Ref: $transactionRef');
      debugPrint('🔵 County: ${county.name}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/stkpush'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'phoneNumber': formattedPhone,
              'amount': amount,
              'meterNumber': meterNumber,
              'userId': userId,
              'countyCode': county.code,
              'countyName': county.name,
              'accountReference': 'Water Payment',
              'transactionDesc': 'Water bill payment for ${county.name}',
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔵 STK Push Response Status: ${response.statusCode}');
      debugPrint('🔵 STK Push Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats
        bool isSuccess = false;
        String? checkoutRequestId;
        String? merchantRequestId;
        String? errorMessage;
        String? successMessage;

        if (data.containsKey('success') && data['success'] == true) {
          isSuccess = true;
          checkoutRequestId =
              data['CheckoutRequestID'] ?? data['checkoutRequestID'];
          merchantRequestId =
              data['MerchantRequestID'] ?? data['merchantRequestID'];
          successMessage = data['message'] ??
              data['CustomerMessage'] ??
              'STK Push sent successfully';
        } else if (data.containsKey('CheckoutRequestID')) {
          isSuccess = true;
          checkoutRequestId = data['CheckoutRequestID'];
          merchantRequestId = data['MerchantRequestID'];
          successMessage =
              data['ResponseDescription'] ?? 'STK Push sent successfully';
        } else if (data.containsKey('error')) {
          errorMessage = data['error'];
        } else if (data.containsKey('errorMessage')) {
          errorMessage = data['errorMessage'];
        } else {
          errorMessage = 'Invalid response format from server';
        }

        if (isSuccess && checkoutRequestId != null) {
          // Save transaction to Firestore
          await _saveTransaction(
            userId: userId,
            userName: fullName,
            userEmail: userDetails['email'] ?? '',
            meterNumber: meterNumber,
            amount: amount,
            litres: litres,
            phone: formattedPhone,
            transactionRef: transactionRef,
            county: county,
            mpesaResponse: data,
            checkoutRequestId: checkoutRequestId,
          );

          // Start checking payment status
          _startPaymentStatusChecker(transactionRef, checkoutRequestId);

          return {
            'status': 'pending',
            'reference': transactionRef,
            'document_id': _generateDocumentId(fullName),
            'mpesa_ref': checkoutRequestId,
            'merchant_ref': merchantRequestId,
            'message':
                successMessage ?? 'M-Pesa STK Push sent to $formattedPhone',
            'litres': litres,
            'county': county.name,
            'water_rate': county.waterRate,
            'phone': formattedPhone,
            'user_name': fullName,
            'note': 'Check your phone for payment prompt',
            'checkout_request_id': checkoutRequestId,
          };
        } else {
          throw Exception(errorMessage ?? 'Payment initiation failed');
        }
      } else {
        debugPrint('🔴 Server Error: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ??
            errorData['errorMessage'] ??
            'Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔴 Nairobi payment error: $e');
      if (e is TimeoutException) {
        throw Exception('Payment request timeout. Please try again.');
      }
      throw Exception('Payment initiation failed: ${e.toString()}');
    }
  }

  void _startPaymentStatusChecker(
      String transactionRef, String checkoutRequestId) {
    // Cancel any existing timer for this transaction
    _statusCheckTimers[transactionRef]?.cancel();

    // Start new timer to check status every 5 seconds for 2 minutes
    final timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status = await _queryPaymentStatus(checkoutRequestId);

        if (status['status'] == 'successful' || status['status'] == 'failed') {
          // Stop checking when payment is finalized
          timer.cancel();
          _statusCheckTimers.remove(transactionRef);

          // Update transaction in Firestore
          await _updateTransactionFromCallback(transactionRef, status);
        }
      } catch (e) {
        debugPrint('Status check error: $e');
      }

      // Stop checking after 2 minutes
      if (timer.tick >= 24) {
        // 24 * 5 seconds = 120 seconds
        timer.cancel();
        _statusCheckTimers.remove(transactionRef);
      }
    });

    _statusCheckTimers[transactionRef] = timer;
  }

  Future<Map<String, dynamic>> _queryPaymentStatus(
      String checkoutRequestId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/query'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CheckoutRequestID': checkoutRequestId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse M-Pesa response
        final resultCode = data['ResultCode']?.toString() ??
            data['resultCode']?.toString() ??
            '0';
        final resultDesc = data['ResultDesc']?.toString() ??
            data['resultDesc']?.toString() ??
            '';

        if (resultCode == '0') {
          return {
            'status': 'successful',
            'message': resultDesc,
            'receipt_number':
                data['MpesaReceiptNumber'] ?? data['mpesaReceiptNumber'],
            'transaction_date':
                data['TransactionDate'] ?? data['transactionDate'],
          };
        } else {
          return {
            'status': 'failed',
            'message': resultDesc,
            'error_code': resultCode,
          };
        }
      }

      return {'status': 'pending', 'message': 'Still processing'};
    } catch (e) {
      debugPrint('Query payment status error: $e');
      return {'status': 'pending', 'message': 'Status check failed'};
    }
  }

  Future<void> _updateTransactionFromCallback(
      String transactionRef, Map<String, dynamic> status) async {
    try {
      // Find transaction by transaction_id
      final querySnapshot = await _firestore
          .collection('transactions')
          .where('transaction_id', isEqualTo: transactionRef)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final userId = data['user_info']?['user_id'] ?? '';
        final userName = data['user_info']?['name'] ?? '';

        await updateTransactionStatus(
          userName: userName,
          transactionId: transactionRef,
          status: status['status'],
          userId: userId,
          mpesaReceiptNumber: status['receipt_number'],
          resultDescription: status['message'],
        );
      }
    } catch (e) {
      debugPrint('Update transaction from callback error: $e');
    }
  }

  Future<Map<String, dynamic>> _getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return {
          'name': doc.data()?['name'] ?? '',
          'email': doc.data()?['email'] ?? '',
          'phone': doc.data()?['phone'] ?? '',
        };
      }
      return {'name': '', 'email': '', 'phone': ''};
    } catch (e) {
      return {'name': '', 'email': '', 'phone': ''};
    }
  }

  String _generateDocumentId(String userName) {
    return '${_cleanUserNameForDocumentId(userName)}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _cleanUserNameForDocumentId(String userName) {
    String clean = userName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    if (clean.isEmpty) {
      clean = 'user';
    }

    if (clean.length > 50) {
      clean = clean.substring(0, 50);
    }

    if (clean.endsWith('_')) {
      clean = clean.substring(0, clean.length - 1);
    }

    return clean;
  }

  Future<void> _saveTransaction({
    required String userId,
    required String userName,
    required String userEmail,
    required String meterNumber,
    required double amount,
    required double litres,
    required String phone,
    required String transactionRef,
    required County county,
    required Map<String, dynamic> mpesaResponse,
    required String checkoutRequestId,
  }) async {
    final now = Timestamp.now();
    String documentId = _generateDocumentId(userName);

    final transactionData = {
      'document_id': documentId,
      'transaction_id': transactionRef,
      'mpesa_checkout_id': checkoutRequestId,
      'mpesa_merchant_id': mpesaResponse['MerchantRequestID'] ??
          mpesaResponse['merchantRequestID'],
      'user_info': {
        'user_id': userId,
        'name': userName,
        'email': userEmail,
        'phone': phone,
        'customer_type': 'water_bill_payer',
      },
      'billing_info': {
        'meter_number': meterNumber,
        'county_code': county.code,
        'county_name': county.name,
        'water_provider': county.waterProvider,
        'customer_care': county.customerCare,
        'water_rate': county.waterRate,
        'litres_purchased': litres,
        'amount_paid': amount,
      },
      'payment_info': {
        'payment_method': 'mpesa',
        'payment_gateway': 'Daraja API',
        'paybill_number': _paybillNumber,
        'currency': 'KES',
        'status': 'pending',
        'checkout_request_id': checkoutRequestId,
        'status_history': [
          {
            'status': 'pending',
            'timestamp': now,
            'note': 'Payment initiated via STK Push',
            'checkout_request_id': checkoutRequestId,
          }
        ],
      },
      'timestamps': {
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'expires_at':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      },
      'metadata': {
        'is_test': false,
        'app_version': '1.0.0',
        'device_info': {},
        'api_response': mpesaResponse,
        'receipt_url': '',
        'water_units_delivered': false,
        'delivery_date': null,
      },
      'search_fields': {
        'user_name_lowercase': userName.toLowerCase(),
        'user_name_clean': _cleanUserNameForDocumentId(userName),
        'meter_number_last4': meterNumber.length > 4
            ? meterNumber.substring(meterNumber.length - 4)
            : meterNumber,
        'county_code_lower': county.code.toLowerCase(),
        'transaction_id': transactionRef,
        'checkout_request_id': checkoutRequestId,
      },
      'analytics': {
        'transaction_category': 'water_bill',
        'payment_channel': 'mobile_money',
        'county_region': county.name,
      }
    };

    // Save to all collections
    await Future.wait([
      _firestore
          .collection('transactions')
          .doc(documentId)
          .set(transactionData),
      _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(documentId)
          .set({
        'document_id': documentId,
        'transaction_id': transactionRef,
        'type': 'water_purchase',
        'amount': amount,
        'litres': litres,
        'county': county.name,
        'status': 'pending',
        'mpesa_ref': checkoutRequestId,
        'timestamp': FieldValue.serverTimestamp(),
        'meter_number': meterNumber,
        'user_name': userName,
        'checkout_request_id': checkoutRequestId,
      }),
      _firestore
          .collection('county_transactions')
          .doc(county.code)
          .collection('payments')
          .doc(documentId)
          .set({
        'document_id': documentId,
        'transaction_id': transactionRef,
        'user_id': userId,
        'user_name': userName,
        'amount': amount,
        'litres': litres,
        'meter_number': meterNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'checkout_request_id': checkoutRequestId,
      }),
    ]);
  }

  Future<void> updateTransactionStatus({
    required String userName,
    required String transactionId,
    required String status,
    required String userId,
    String? mpesaReceiptNumber,
    String? resultDescription,
  }) async {
    final now = Timestamp.now();

    // Find transaction
    final querySnapshot = await _firestore
        .collection('transactions')
        .where('transaction_id', isEqualTo: transactionId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Transaction not found: $transactionId');
    }

    String documentId = querySnapshot.docs.first.id;
    final transactionDoc =
        await _firestore.collection('transactions').doc(documentId).get();
    final countyCode =
        transactionDoc.data()?['billing_info']?['county_code'] ?? '001';

    final updates = {
      'payment_info.status': status,
      'payment_info.status_history': FieldValue.arrayUnion([
        {
          'status': status,
          'timestamp': now,
          'note': resultDescription ?? 'Status updated',
          'mpesa_receipt': mpesaReceiptNumber,
        }
      ]),
      'timestamps.updated_at': FieldValue.serverTimestamp(),
    };

    if (mpesaReceiptNumber != null) {
      updates['payment_info.mpesa_receipt_number'] = mpesaReceiptNumber;
      updates['metadata.receipt_url'] =
          'https://api.safaricom.co.ke/v1/receipts/$mpesaReceiptNumber';
    }

    if (status == 'successful') {
      updates['metadata.water_units_delivered'] = true;
      updates['metadata.delivery_date'] = FieldValue.serverTimestamp();
    }

    // Update all related documents
    await Future.wait([
      _firestore.collection('transactions').doc(documentId).update(updates),
      _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(documentId)
          .update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        if (mpesaReceiptNumber != null) 'mpesa_receipt': mpesaReceiptNumber,
      }),
      _firestore
          .collection('county_transactions')
          .doc(countyCode)
          .collection('payments')
          .doc(documentId)
          .update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        if (mpesaReceiptNumber != null) 'mpesa_receipt': mpesaReceiptNumber,
      }),
    ]);
  }

  @override
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      // First check if transaction exists in Firestore
      final querySnapshot = await _firestore
          .collection('transactions')
          .where('transaction_id', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'status': 'not_found',
          'message': 'Transaction not found',
        };
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final checkoutRequestId = data['payment_info']?['checkout_request_id'] ??
          data['mpesa_checkout_id'];

      if (checkoutRequestId == null) {
        return {
          'status': data['payment_info']?['status'] ?? 'pending',
          'message': 'No checkout request ID found',
        };
      }

      // Query M-Pesa API for status
      final response = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/query'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CheckoutRequestID': checkoutRequestId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final resultCode = result['ResultCode']?.toString() ??
            result['resultCode']?.toString() ??
            '0';

        if (resultCode == '0') {
          return {
            'status': 'successful',
            'message': result['ResultDesc'] ??
                result['resultDesc'] ??
                'Payment successful',
            'receipt_number':
                result['MpesaReceiptNumber'] ?? result['mpesaReceiptNumber'],
            'transaction_date':
                result['TransactionDate'] ?? result['transactionDate'],
            'amount': result['Amount'] ?? result['amount'],
            'phone': result['PhoneNumber'] ?? result['phoneNumber'],
          };
        } else if (resultCode == '1037') {
          return {
            'status': 'pending',
            'message': 'Request timed out. Please try again.',
            'error_code': resultCode,
          };
        } else if (resultCode == '1032') {
          return {
            'status': 'cancelled',
            'message': 'Transaction cancelled by user',
            'error_code': resultCode,
          };
        } else {
          return {
            'status': 'failed',
            'message': result['ResultDesc'] ??
                result['resultDesc'] ??
                'Payment failed',
            'error_code': resultCode,
          };
        }
      }

      // If API fails, return Firestore status
      return {
        'status': data['payment_info']?['status'] ?? 'pending',
        'message': 'Checking status...',
      };
    } catch (e) {
      debugPrint('Check payment status error: $e');
      return {
        'status': 'error',
        'message': 'Failed to check status: ${e.toString()}',
      };
    }
  }

  // ... [Keep other existing methods: getTransactionsWithUsers, getTransactionsForUser, etc.] ...

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy' || data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      debugPrint('Connection test error: $e');
      return false;
    }
  }

  @override
  bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');

    // Accept all common Kenyan phone formats
    final patterns = [
      r'^01[0-9]{8}$', // Landline: 01XXXXXXXX
      r'^07[0-9]{8}$', // Mobile: 07XXXXXXXX
      r'^011[0-9]{7}$', // Landline with area code: 011XXXXXXX
      r'^\+2541[0-9]{8}$', // International landline: +2541XXXXXXXX
      r'^\+2547[0-9]{8}$', // International mobile: +2547XXXXXXXX
      r'^2541[0-9]{8}$', // Local international landline: 2541XXXXXXXX
      r'^2547[0-9]{8}$', // Local international mobile: 2547XXXXXXXX
      r'^1[0-9]{9}$', // Landline without 0: 1XXXXXXXXX
      r'^7[0-9]{8}$', // Mobile without 0 or 254: 7XXXXXXXX
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern).hasMatch(cleaned)) {
        return true;
      }
    }

    return false;
  }

  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    // Remove + if present
    if (phone.startsWith('+254')) {
      phone = phone.substring(1); // Remove + to get 254...
    }

    // Handle mobile numbers starting with 0
    if (phone.startsWith('0') && phone.length == 10) {
      return '254${phone.substring(1)}';
    }

    // Handle mobile numbers starting with 7 (9 digits)
    if (phone.startsWith('7') && phone.length == 9) {
      return '254$phone';
    }

    // Handle landline numbers (keep as is)
    if ((phone.startsWith('01') || phone.startsWith('011')) &&
        (phone.length == 10 || phone.length == 11)) {
      return phone;
    }

    // If already starts with 254, return as is
    if (phone.startsWith('254')) {
      return phone;
    }

    // Default return
    return phone;
  }

  @override
  String getPaybillNumber() => _paybillNumber;

  @override
  String getTillNumber() => '';

  @override
  String getAccountPrefix() => 'NAIROBIWATER';

  // Dispose method to clean up timers
  void dispose() {
    for (final timer in _statusCheckTimers.values) {
      timer.cancel();
    }
    _statusCheckTimers.clear();
  }
}

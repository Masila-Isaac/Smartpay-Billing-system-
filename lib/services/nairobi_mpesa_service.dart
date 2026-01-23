import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart';
import 'package:smartpay/services/county_payment_factory.dart';

class NairobiMpesaService implements CountyPaymentService {
  final String _baseUrl = 'https://smartpay-billing.onrender.com';
  final String _paybillNumber = '174379';
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
      final formattedPhone = _formatPhone(phone);
      final litres = county.calculateLitres(amount);
      final transactionRef =
          'NAI${DateTime.now().millisecondsSinceEpoch}${meterNumber.substring(meterNumber.length - 4)}';

      // Fetch user details
      final userDetails = await _getUserDetails(userId);
      final fullName = userDetails['name'] ?? 'Unknown';

      final response = await http.post(
        Uri.parse('$_baseUrl/mpesa/stkpush'),
        headers: {'Content-Type': 'application/json'},
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
            'user_name': fullName,
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

    final transactionData = {
      'transaction_id': transactionRef,
      'mpesa_checkout_id': checkoutRequestId,
      'mpesa_merchant_id': mpesaResponse['MerchantRequestID'],
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
        'status_history': [
          {
            'status': 'pending',
            'timestamp':
                now, // Use Timestamp.now() instead of FieldValue.serverTimestamp()
            'note': 'Payment initiated via STK Push'
          }
        ],
      },
      'timestamps': {
        'created_at':
            FieldValue.serverTimestamp(), // This is OK here (not in array)
        'updated_at':
            FieldValue.serverTimestamp(), // This is OK here (not in array)
        'expires_at':
            Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
      },
      'metadata': {
        'is_test': true,
        'app_version': '1.0.0',
        'device_info': {},
        'api_response': mpesaResponse,
        'receipt_url': '',
        'water_units_delivered': false,
        'delivery_date': null,
      },
      'search_fields': {
        'user_name_lowercase': userName.toLowerCase(),
        'meter_number_last4': meterNumber.length > 4
            ? meterNumber.substring(meterNumber.length - 4)
            : meterNumber,
        'county_code_lower': county.code.toLowerCase(),
      },
      'analytics': {
        'transaction_category': 'water_bill',
        'payment_channel': 'mobile_money',
        'county_region': county.name,
      }
    };

    await _firestore
        .collection('transactions')
        .doc(transactionRef)
        .set(transactionData);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionRef)
        .set({
      'transaction_id': transactionRef,
      'type': 'water_purchase',
      'amount': amount,
      'litres': litres,
      'county': county.name,
      'status': 'pending',
      'mpesa_ref': checkoutRequestId,
      'timestamp': FieldValue.serverTimestamp(), // OK here
      'meter_number': meterNumber,
      'user_name': userName,
    });

    await _firestore
        .collection('county_transactions')
        .doc(county.code)
        .collection('payments')
        .doc(transactionRef)
        .set({
      'transaction_id': transactionRef,
      'user_id': userId,
      'user_name': userName,
      'amount': amount,
      'litres': litres,
      'meter_number': meterNumber,
      'timestamp': FieldValue.serverTimestamp(), // OK here
      'status': 'pending',
    });
  }

  Future<void> updateTransactionStatus({
    required String transactionId,
    required String status,
    required String userId,
    String? mpesaReceiptNumber,
    String? resultDescription,
  }) async {
    final now = Timestamp.now();

    final updates = {
      'payment_info.status': status,
      'payment_info.status_history': FieldValue.arrayUnion([
        {
          'status': status,
          'timestamp':
              now, // Use Timestamp.now() instead of FieldValue.serverTimestamp()
          'note': resultDescription ?? 'Status updated',
          'mpesa_receipt': mpesaReceiptNumber
        }
      ]),
      'timestamps.updated_at': FieldValue.serverTimestamp(),
    };

    if (mpesaReceiptNumber != null) {
      updates['metadata.receipt_url'] =
          'https://api.safaricom.co.ke/v1/receipts/$mpesaReceiptNumber';
      updates['payment_info.mpesa_receipt_number'] = mpesaReceiptNumber;
    }

    if (status == 'completed') {
      updates['metadata.water_units_delivered'] = true;
      updates['metadata.delivery_date'] = FieldValue.serverTimestamp();
    }

    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .update(updates);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId)
        .update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
      if (mpesaReceiptNumber != null) 'mpesa_receipt': mpesaReceiptNumber,
    });
  }

  Stream<List<Map<String, dynamic>>> getTransactionsWithUsers({
    String? countyCode,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    var query = _firestore
        .collection('transactions')
        .orderBy('timestamps.created_at', descending: true)
        .limit(limit);

    if (countyCode != null) {
      query = query.where('billing_info.county_code', isEqualTo: countyCode);
    }

    if (startDate != null) {
      query = query.where('timestamps.created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamps.created_at',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'user_name': data['user_info']?['name'] ?? 'Unknown',
          'user_email': data['user_info']?['email'] ?? '',
          'user_phone': data['user_info']?['phone'] ?? '',
          'amount': data['billing_info']?['amount_paid'] ?? 0,
          'litres': data['billing_info']?['litres_purchased'] ?? 0,
          'meter_number': data['billing_info']?['meter_number'] ?? '',
          'county': data['billing_info']?['county_name'] ?? '',
          'status': data['payment_info']?['status'] ?? 'pending',
          'created_at': data['timestamps']?['created_at'],
          'mpesa_receipt': data['payment_info']?['mpesa_receipt_number'] ?? '',
        };
      }).toList();
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

  @override
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
  @override
  bool isValidPhone(String phone) {
    // Clean the phone number
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');

    // Check for 01XXXXXXXX (10 digits) - Landline numbers
    if (RegExp(r'^01[0-9]{8}$').hasMatch(cleaned)) return true;

    // Check for 07XXXXXXXX (10 digits) - Mobile numbers
    if (RegExp(r'^07[0-9]{8}$').hasMatch(cleaned)) return true;

    // Check for 011XXXXXXXX (11 digits) - Landline numbers with area code
    if (RegExp(r'^011[0-9]{7}$').hasMatch(cleaned)) return true;

    // Check for +2541XXXXXXXX (13 digits) - International landline format
    if (RegExp(r'^\+2541[0-9]{8}$').hasMatch(cleaned)) return true;

    // Check for +2547XXXXXXXX (13 digits) - International mobile format
    if (RegExp(r'^\+2547[0-9]{8}$').hasMatch(cleaned)) return true;

    // Check for 2541XXXXXXXX (12 digits) - Local international landline format
    if (RegExp(r'^2541[0-9]{8}$').hasMatch(cleaned)) return true;

    // Check for 2547XXXXXXXX (12 digits) - Local international mobile format
    if (RegExp(r'^2547[0-9]{8}$').hasMatch(cleaned)) return true;

    return false;
  }

  String _formatPhone(String phone) {
    // Remove all spaces
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    // If starts with +254, remove the +
    if (phone.startsWith('+254')) {
      phone = phone.substring(1);
    }

    // Handle landline numbers (01XXXXXXXX)
    if (phone.startsWith('01') && phone.length == 10) {
      return phone; // Keep as is for landline
    }

    // Handle landline numbers with area code (011XXXXXXX)
    if (phone.startsWith('011') && phone.length == 11) {
      return phone; // Keep as is for landline with area code
    }

    // If starts with 0 (mobile), replace with 254
    if (phone.startsWith('0') && phone.length == 10) {
      return '254${phone.substring(1)}';
    }

    // If starts with 7 and is 9 digits (excluding 254), add 254
    if (phone.startsWith('7') && phone.length == 9) {
      return '254$phone';
    }

    // If starts with 1 (landline without 254), check length
    if (phone.startsWith('1') && phone.length == 10) {
      return phone; // Keep as is for landline
    }

    // If already starts with 254, return as is
    if (phone.startsWith('254')) {
      return phone;
    }

    // Return original if no match
    return phone;
  }

  @override
  String getPaybillNumber() => _paybillNumber;

  @override
  String getTillNumber() => '';

  @override
  String getAccountPrefix() => 'NAIROBIWATER';
}

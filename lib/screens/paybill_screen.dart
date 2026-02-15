import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/services/county_payment_factory.dart';
import 'package:smartpay/config/counties.dart';
import 'package:smartpay/screens/dashboard.dart';

class PayBillScreen extends StatefulWidget {
  final String meterNumber;
  final String userId;
  final String countyCode;

  const PayBillScreen({
    super.key,
    required this.meterNumber,
    required this.userId,
    required this.countyCode,
  });

  @override
  State<PayBillScreen> createState() => _PayBillScreenState();
}

class _PayBillScreenState extends State<PayBillScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController meterNumberController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  bool _isLoading = false;
  bool _serverConnected = true;
  bool _paymentCompleted = false;
  String? _paymentReference;
  String? _mpesaCheckoutId;
  String _paymentStatus = 'pending';
  double _litresPurchased = 0.0;
  bool _redirecting = false;
  bool _isInitializing = true;
  Timer? _paymentStatusTimer;
  String? _paymentMessage;
  String? _mpesaReceiptNumber;

  // User details variables
  String _userName = '';
  String _userEmail = '';

  County? _county;
  late CountyPaymentService _paymentService;
  List<Map<String, dynamic>> _paymentMethods = [];
  String _selectedPaymentMethod = '';
  String _paybillNumber = '';
  String _tillNumber = '';
  Color _primaryColor = Colors.blueAccent;
  double _waterRate = 1.0;
  double _litresToPurchase = 0.0;

  // API Base URL
  final String apiBaseUrl = 'https://smartpay-billing.onrender.com';

  @override
  void initState() {
    super.initState();
    debugPrint('County code received: ${widget.countyCode}');

    // Initialize synchronously first
    _initializeSync();

    // Then load user details asynchronously
    _loadUserDetails().then((_) {
      _initializeAsync();
      _testServerConnection();
    });
  }

  @override
  void dispose() {
    _paymentStatusTimer?.cancel();
    phoneController.dispose();
    meterNumberController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _initializeSync() {
    try {
      final loadedCounty = CountyConfig.getCounty(widget.countyCode);
      _county = loadedCounty;

      try {
        if (_county!.theme['primaryColor'] != null &&
            _county!.theme['primaryColor'] is String) {
          final colorStr = _county!.theme['primaryColor'] as String;
          _primaryColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
        } else {
          _primaryColor = Colors.blueAccent;
        }
      } catch (e) {
        debugPrint('Error parsing color: $e');
        _primaryColor = Colors.blueAccent;
      }

      _waterRate = _county!.waterRate ?? 1.0;
      _paybillNumber = _county!.paybillNumber ?? '';
      _tillNumber = _county!.tillNumber ?? '';

      debugPrint('County loaded: ${_county!.name}, Water rate: $_waterRate');
    } catch (e) {
      debugPrint('Using default county configuration: $e');
      _county = County(
        code: widget.countyCode,
        name: 'Water Service',
        waterProvider: 'Local Provider',
        paybillNumber: '123456',
        tillNumber: '123456',
        waterRate: 1.0,
        customerCare: '0700 000 000',
        countyLogo: 'assets/county/default.png',
        theme: {'primaryColor': '#1E88E5'},
        enabled: true,
        paymentGateway: '',
        paymentMethods: {},
      );
      _primaryColor = Colors.blueAccent;
      _waterRate = 1.0;
      _paybillNumber = '123456';
      _tillNumber = '123456';
    }

    try {
      _paymentMethods =
          CountyPaymentFactory.getEnabledPaymentMethods(widget.countyCode) ??
              [];
      _selectedPaymentMethod =
          _paymentMethods.isNotEmpty ? _paymentMethods.first['id'] : '';
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
      _paymentMethods = [];
      _selectedPaymentMethod = '';
    }

    _updatePaymentService();
    _initializeForm();
  }

  Future<void> _loadUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        setState(() {
          _userName = data['name']?.toString() ?? 'User';
          _userEmail = data['email']?.toString() ?? '';
        });
        debugPrint('Loaded user: $_userName');

        final phone = data['phone']?.toString() ?? '';
        if (phone.isNotEmpty) {
          phoneController.text = phone;
        }
      }
    } catch (e) {
      debugPrint('User details load error: $e');
    }
  }

  void _initializeAsync() {
    setState(() {
      _isInitializing = false;
    });
  }

  void _initializeForm() {
    if (widget.meterNumber.isNotEmpty) {
      meterNumberController.text = widget.meterNumber;
    }
  }

  void _updatePaymentService() {
    try {
      _paymentService = CountyPaymentFactory.getService(
        widget.countyCode,
        _selectedPaymentMethod,
      ) as CountyPaymentService;
    } catch (e) {
      debugPrint('Error creating payment service: $e');
      _paymentService = _createRealPaymentService();
    }
  }

  CountyPaymentService _createRealPaymentService() {
    return _RealCountyPaymentService(apiBaseUrl: apiBaseUrl);
  }

  Future<void> _testServerConnection() async {
    try {
      final connected = await _paymentService.testConnection();
      setState(() => _serverConnected = connected);
    } catch (e) {
      debugPrint('Connection test error: $e');
      setState(() => _serverConnected = false);
    }
  }

  void _updateLitresCalculation(String amountText) {
    final amount = double.tryParse(amountText) ?? 0.0;
    setState(() {
      _litresToPurchase = _county?.calculateLitres(amount) ?? 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _county == null) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _paymentCompleted ? 'Payment Status' : 'Pay Water Bill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: _navigateBack,
        ),
      ),
      backgroundColor: Colors.white,
      body: _paymentCompleted ? _buildSuccessScreen() : _buildPaymentForm(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 20),
            Text(
              'Loading payment information...',
              style: TextStyle(color: _primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    if (_county == null) return _buildLoadingScreen();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 25),
          _buildCountyInfoCard(),
          _buildWaterRateInfo(),
          if (!_serverConnected) _buildServerWarning(),
          if (_paymentMethods.isNotEmpty) _buildPaymentMethodSelector(),
          const SizedBox(height: 16),
          _buildPaymentFormContainer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.water_drop, color: _primaryColor, size: 40),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SmartPay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              _county!.name,
              style: TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountyInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _primaryColor.withOpacity(0.1),
                  image: _county!.countyLogo.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(_county!.countyLogo),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _county!.countyLogo.isEmpty
                    ? Icon(
                        Icons.location_city,
                        color: _primaryColor,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _county!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      _county!.waterProvider,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paybill',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paybillNumber.isNotEmpty
                          ? _paybillNumber
                          : 'Not Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_tillNumber.isNotEmpty && _tillNumber != 'N/A')
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Till Number',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tillNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_county!.customerCare.isNotEmpty)
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Customer Care: ${_county!.customerCare}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWaterRateInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.water_drop,
              color: _primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Water Rate',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${_waterRate.toStringAsFixed(2)} per litre',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (_litresToPurchase > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You will receive ${_litresToPurchase.toStringAsFixed(2)} litres',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${_county!.name} payment server not connected. Payments may fail.",
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          TextButton(
            onPressed: _testServerConnection,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange[800],
            ),
            child: const Text("RETRY"),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethod == method['id'];
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedPaymentMethod = method['id'];
                  _updatePaymentService();
                  if (method['paybill'] != null) {
                    _paybillNumber = method['paybill']!;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        image: method['logo'] != null
                            ? DecorationImage(
                                image: AssetImage(method['logo']!),
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: method['logo'] == null
                          ? Icon(
                              Icons.payment,
                              size: 20,
                              color: isSelected ? _primaryColor : Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      method['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _primaryColor : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentFormContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fa),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildTextField(
            label: 'Meter Number',
            controller: meterNumberController,
            hintText: 'Enter your meter number',
            icon: Icons.speed_outlined,
            enabled: widget.meterNumber.isEmpty,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Amount (KES)',
            controller: amountController,
            hintText: 'e.g. 5, 10, 50, 100',
            icon: Icons.attach_money_outlined,
            keyboardType: TextInputType.number,
            onChanged: _updateLitresCalculation,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Phone Number',
            controller: phoneController,
            hintText: 'e.g., 07XXXXXXXX, 01XXXXXXXX, or 254XXXXXXXXX',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "KES ${_waterRate.toStringAsFixed(2)} = 1 litre of water",
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "You will receive a payment prompt on your phone",
                        style: TextStyle(
                          color: _primaryColor.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _serverConnected && _isPhoneValid() && _isAmountValid()
                        ? _primaryColor
                        : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _serverConnected &&
                      !_isLoading &&
                      _isPhoneValid() &&
                      _isAmountValid()
                  ? _handlePayment
                  : null,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'PROCEED TO PAY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final isFailed = _paymentStatus == 'failed';
    final isPending = _paymentStatus == 'pending';
    final isSuccess = _paymentStatus == 'successful';
    final isCancelled = _paymentStatus == 'cancelled';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isFailed
                  ? Colors.red.withOpacity(0.1)
                  : isPending
                      ? Colors.orange.withOpacity(0.1)
                      : isCancelled
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFailed
                  ? Icons.error_outline
                  : isPending
                      ? Icons.pending_outlined
                      : isCancelled
                          ? Icons.cancel_outlined
                          : Icons.check_circle,
              color: isFailed
                  ? Colors.red
                  : isPending
                      ? Colors.orange
                      : isCancelled
                          ? Colors.grey
                          : Colors.green,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFailed
                ? 'Payment Failed'
                : isPending
                    ? 'Payment Pending'
                    : isCancelled
                        ? 'Payment Cancelled'
                        : 'Payment Successful!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isFailed
                  ? Colors.red
                  : isPending
                      ? Colors.orange
                      : isCancelled
                          ? Colors.grey
                          : Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'KES ${amountController.text}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Meter: ${meterNumberController.text}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Water Purchased: ${_litresPurchased.toStringAsFixed(2)} litres',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'County: ${_county?.name ?? "Unknown"}',
            style: TextStyle(
              fontSize: 14,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_paymentReference != null && _paymentReference != 'N/A') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reference: $_paymentReference',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (_mpesaReceiptNumber != null &&
              _mpesaReceiptNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'MPesa Receipt: $_mpesaReceiptNumber',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _paymentMessage ??
                (isPending
                    ? 'Please check your phone to complete the payment. We are checking the payment status...'
                    : isFailed
                        ? 'Payment failed. Please try again or contact support.'
                        : isCancelled
                            ? 'Payment was cancelled. You can try again.'
                            : 'Your payment has been processed successfully!'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildActionButtons(isFailed, isPending, isSuccess, isCancelled),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      bool isFailed, bool isPending, bool isSuccess, bool isCancelled) {
    if (isFailed || isCancelled) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _redirectToPaymentScreen(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFailed ? Colors.red : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 20),
              const SizedBox(width: 8),
              Text(
                'TRY AGAIN',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isPending) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _redirectToPaymentScreen(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: _primaryColor),
                  ),
                  child: Text(
                    'Make Another Payment',
                    style: TextStyle(color: _primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _checkPaymentStatus(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Check Status'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Auto-checking status every 10 seconds...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    } else {
      // Success
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _redirectToDashboard(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'GO TO DASHBOARD',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled && !_isLoading,
          keyboardType: keyboardType,
          onChanged: onChanged ?? (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  bool _isPhoneValid() {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) return false;

    try {
      if (_paymentService.isValidPhone(phone)) {
        return true;
      }
    } catch (e) {
      debugPrint('Phone validation error: $e');
    }

    final phoneRegex = RegExp(r'^(\+?254|0)?[17][0-9]{8,9}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'\s+'), ''));
  }

  bool _isAmountValid() {
    final amountText = amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText) ?? 0.0;
    return amount > 0;
  }

  Future<void> _handlePayment() async {
    FocusScope.of(context).unfocus();

    if (_county == null) {
      _showErrorDialog('County information error. Please restart the app.');
      return;
    }

    final phone = phoneController.text.trim();
    final meterNumber = meterNumberController.text.trim();
    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    final litres = _county!.calculateLitres(amount);

    if (phone.isEmpty) {
      _showErrorDialog('Please enter your phone number');
      return;
    }

    if (meterNumber.isEmpty) {
      _showErrorDialog('Please enter your meter number');
      return;
    }

    if (amountText.isEmpty) {
      _showErrorDialog('Please enter an amount');
      return;
    }

    if (amount <= 0) {
      _showErrorDialog('Please enter a valid amount greater than 0 KES');
      return;
    }

    try {
      if (!_paymentService.isValidPhone(phone)) {
        _showErrorDialog(
            'Please enter a valid phone number for ${_county!.name}');
        return;
      }
    } catch (e) {
      _showErrorDialog(
          'Phone validation error. Please check your phone number.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${_county!.name} Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: KES ${amount.toStringAsFixed(2)}'),
            Text('Litres: ${litres.toStringAsFixed(2)} litres'),
            Text('Phone: $phone'),
            Text('Meter: $meterNumber'),
            Text('County: ${_county!.name}'),
            const SizedBox(height: 16),
            if (amount < 10)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Note: Amount is less than KES 10',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'You will receive a payment prompt on your phone to complete the payment.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: const Text('Confirm & Pay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Please log in to make payments");
      }

      debugPrint('🔵 Sending STK Push to: $phone');
      debugPrint('🔵 Amount: $amount');
      debugPrint('🔵 Meter: $meterNumber');
      debugPrint('🔵 County: ${_county!.name}');

      // Call payment service to send STK push
      final result = await _paymentService.initiatePayment(
        userId: user.uid,
        phone: phone,
        amount: amount,
        meterNumber: meterNumber,
        county: _county!,
      );

      debugPrint('🔵 Payment initiation result: $result');

      final status = result['status']?.toString() ?? 'pending';
      _paymentReference = result['reference']?.toString();
      _mpesaCheckoutId = result['mpesa_ref']?.toString();
      _paymentMessage = result['message']?.toString();

      if (status == 'pending' && _mpesaCheckoutId != null) {
        // STK push sent successfully
        setState(() {
          _paymentCompleted = true;
          _paymentStatus = 'pending';
          _litresPurchased = litres;
          _isLoading = false;
        });

        // Start checking payment status periodically
        _startPaymentStatusChecker();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_paymentMessage ??
                  'Payment request sent to your phone. Please check your phone to complete the payment.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Something went wrong with STK push
        setState(() => _isLoading = false);
        throw Exception(
            result['error']?.toString() ?? 'Failed to send STK push');
      }
    } catch (e) {
      debugPrint('🔴 Payment error: $e');
      if (mounted) {
        _showErrorDialog('Payment failed: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPaymentStatusChecker() {
    _paymentStatusTimer?.cancel();
    _paymentStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_paymentStatus == 'pending' && mounted) {
        _checkPaymentStatus();
      } else {
        timer.cancel();
      }

      // Stop checking after 3 minutes (18 checks * 10 seconds)
      if (timer.tick >= 18) {
        timer.cancel();
        if (mounted && _paymentStatus == 'pending') {
          setState(() {
            _paymentMessage =
                'Payment check timeout. Please check your phone or try again.';
          });
        }
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentReference == null) return;

    try {
      debugPrint('🔄 Checking payment status for: $_paymentReference');

      // Add timeout to prevent hanging
      final statusResult = await _paymentService
          .checkPaymentStatus(_paymentReference!)
          .timeout(const Duration(seconds: 10));

      debugPrint('🔄 Payment status result: $statusResult');

      final newStatus = statusResult['status']?.toString() ?? 'pending';
      final newMessage = statusResult['message']?.toString();
      final receiptNumber = statusResult['receipt_number']?.toString();

      if (mounted) {
        setState(() {
          _paymentStatus = newStatus;
          _paymentMessage = newMessage;
          if (receiptNumber != null && receiptNumber.isNotEmpty) {
            _mpesaReceiptNumber = receiptNumber;
          }
        });

        if (newStatus == 'successful') {
          // Update water usage for successful payment
          final amount = double.tryParse(amountController.text) ?? 0.0;
          final litres = _county?.calculateLitres(amount) ?? 0.0;

          try {
            await _updateWaterUsageAfterPayment(
              meterNumber: meterNumberController.text.trim(),
              userId: widget.userId,
              litresPurchased: litres,
              amount: amount,
              county: _county!,
            );

            debugPrint('✅ Water usage updated successfully');
          } catch (e) {
            debugPrint('❌ Water usage update error: $e');
          }

          _paymentStatusTimer?.cancel();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Payment completed successfully! Receipt: $_mpesaReceiptNumber'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else if (newStatus == 'failed' || newStatus == 'cancelled') {
          _paymentStatusTimer?.cancel();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment $newStatus. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Status check error: $e');

      // Don't cancel timer on network errors, just log and continue
      if (mounted) {
        setState(() {
          _paymentMessage = 'Checking status... (${e.toString()})';
        });
      }
    }
  }

  void _redirectToDashboard() {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Dashboard(
            userId: widget.userId,
            meterNumber: widget.meterNumber,
            userName: _userName,
            userEmail: _userEmail,
            countyCode: widget.countyCode,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Dashboard navigation error: $e');
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  void _redirectToPaymentScreen() {
    _paymentStatusTimer?.cancel();
    setState(() {
      _paymentCompleted = false;
      _paymentStatus = 'pending';
      _redirecting = false;
      _isLoading = false;
      _paymentMessage = null;
      _mpesaReceiptNumber = null;
    });
  }

  void _navigateBack() {
    try {
      if (_paymentCompleted &&
          (_paymentStatus == 'successful' || _paymentStatus == 'pending')) {
        _redirectToDashboard();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Navigate back error: $e');
      Navigator.pop(context);
    }
  }

  Future<void> _updateWaterUsageAfterPayment({
    required String meterNumber,
    required String userId,
    required double litresPurchased,
    required double amount,
    required County county,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      debugPrint('💧 Updating water usage after payment');

      final waterUsageDoc =
          await firestore.collection('waterUsage').doc(meterNumber).get();

      if (waterUsageDoc.exists && waterUsageDoc.data() != null) {
        final currentData = waterUsageDoc.data()!;

        double currentReading =
            (currentData['currentReading'] ?? 0.0).toDouble();
        double remainingUnits =
            (currentData['remainingUnits'] ?? 0.0).toDouble();
        double totalUnitsPurchased =
            (currentData['totalUnitsPurchased'] ?? 0.0).toDouble();

        double newCurrentReading = currentReading + litresPurchased;
        double newRemainingUnits = remainingUnits + litresPurchased;
        double newTotalPurchased = totalUnitsPurchased + litresPurchased;

        await firestore.collection('waterUsage').doc(meterNumber).update({
          'currentReading': newCurrentReading,
          'remainingUnits': newRemainingUnits,
          'totalUnitsPurchased': newTotalPurchased,
          'countyCode': county.code,
          'countyName': county.name,
          'waterRate': county.waterRate,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        await firestore.collection('clients').doc(meterNumber).update({
          'remainingLitres': newRemainingUnits,
          'totalLitresPurchased': newTotalPurchased,
          'county': county.code,
          'lastTopUp': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        await firestore.collection('dashboard_data').doc(userId).set({
          'remainingBalance': newRemainingUnits,
          'totalPurchased': newTotalPurchased,
          'meterNumber': meterNumber,
          'countyCode': county.code,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ Water usage updated successfully');
      } else {
        await firestore.collection('waterUsage').doc(meterNumber).set({
          'meterNumber': meterNumber,
          'userId': userId,
          'accountNumber': '',
          'countyCode': county.code,
          'countyName': county.name,
          'waterRate': county.waterRate,
          'currentReading': litresPurchased,
          'previousReading': 0.0,
          'remainingUnits': litresPurchased,
          'totalUnitsPurchased': litresPurchased,
          'unitsConsumed': 0.0,
          'lastReadingDate': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        debugPrint('✅ New water usage document created');
      }

      // Also save payment record
      await firestore.collection('payments').add({
        'userId': userId,
        'meterNumber': meterNumber,
        'amount': amount,
        'litres': litresPurchased,
        'countyCode': county.code,
        'countyName': county.name,
        'reference': _paymentReference,
        'mpesaReceipt': _mpesaReceiptNumber,
        'status': _paymentStatus,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating water usage: $e');
      throw Exception('Failed to update water usage: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: _primaryColor),
            const SizedBox(width: 8),
            const Text('Payment Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Real Payment Service Implementation
class _RealCountyPaymentService implements CountyPaymentService {
  final String apiBaseUrl;

  _RealCountyPaymentService({required this.apiBaseUrl});

  @override
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/mpesa/stkpush'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'phoneNumber': phone,
              'amount': amount,
              'meterNumber': meterNumber,
              'userId': userId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📥 STK Push Response Status: ${response.statusCode}');
      debugPrint('📥 STK Push Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return {
            'status': 'pending',
            'reference': data['CheckoutRequestID'] ?? data['MerchantRequestID'],
            'mpesa_ref': data['CheckoutRequestID'],
            'message':
                data['message'] ?? data['CustomerMessage'] ?? 'STK Push sent',
          };
        } else {
          throw Exception(data['error'] ?? 'Payment initiation failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Initiate payment error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/payment/$transactionId'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Status Check Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['payment'] != null) {
          final payment = data['payment'];

          // Map server status to expected status
          String status = 'pending';
          if (payment['status'] == 'Success') {
            status = 'successful';
          } else if (payment['status'] == 'Failed') {
            status = 'failed';
          }

          // Extract receipt number if available
          String? receiptNumber;
          if (payment['receiptNumber'] != null) {
            receiptNumber = payment['receiptNumber'];
          } else if (payment['callbackData'] != null &&
              payment['callbackData']['stkCallback'] != null &&
              payment['callbackData']['stkCallback']['CallbackMetadata'] !=
                  null) {
            final metadata = payment['callbackData']['stkCallback']
                ['CallbackMetadata']['Item'];
            if (metadata != null && metadata is List) {
              final receiptItem = metadata.firstWhere(
                (item) => item['Name'] == 'MpesaReceiptNumber',
                orElse: () => null,
              );
              if (receiptItem != null) {
                receiptNumber = receiptItem['Value']?.toString();
              }
            }
          }

          return {
            'status': status,
            'message': payment['statusMessage'] ??
                'Payment status: ${payment['status']}',
            'receipt_number': receiptNumber,
          };
        }
      }

      return {'status': 'pending', 'message': 'Status check pending'};
    } catch (e) {
      debugPrint('❌ Status check error: $e');
      return {'status': 'pending', 'message': 'Status check failed: $e'};
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/health'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test error: $e');
      return false;
    }
  }

  @override
  bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final phoneRegex = RegExp(r'^(\+?254|0)?[17][0-9]{8,9}$');
    return phoneRegex.hasMatch(cleaned);
  }

  @override
  String getPaybillNumber() => '174379';

  @override
  String getTillNumber() => '000000';

  @override
  String getAccountPrefix() => 'WATER';
}

// Keep the CountyPaymentService interface if not already defined elsewhere
abstract class CountyPaymentService {
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  });

  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId);
  Future<bool> testConnection();
  bool isValidPhone(String phone);
  String getPaybillNumber();
  String getTillNumber();
  String getAccountPrefix();
}

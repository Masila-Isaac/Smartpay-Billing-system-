import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/services/county_payment_factory.dart';
import 'package:smartpay/config/counties.dart';

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
  String _paymentStatus = 'pending';
  double _litresPurchased = 0.0;
  bool _redirecting = false;

  late County _county;
  late CountyPaymentService _paymentService;
  List<Map<String, dynamic>> _paymentMethods = [];
  String _selectedPaymentMethod = '';
  String _paybillNumber = '';
  String _tillNumber = '';
  Color _primaryColor = Colors.blueAccent;
  double _waterRate = 1.0;
  double _litresToPurchase = 0.0;

  @override
  void initState() {
    super.initState();

    debugPrint('County code received: ${widget.countyCode}');

    try {
      // Try to load county
      final loadedCounty = CountyConfig.getCounty(widget.countyCode);
      if (loadedCounty != null) {
        _county = loadedCounty;

        // Safely parse color
        try {
          if (_county.theme != null &&
              _county.theme['primaryColor'] != null &&
              _county.theme['primaryColor'] is String) {
            final colorStr = _county.theme['primaryColor'] as String;
            _primaryColor =
                Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
          } else {
            _primaryColor = Colors.blueAccent;
          }
        } catch (e) {
          debugPrint('Error parsing color: $e');
          _primaryColor = Colors.blueAccent;
        }

        _waterRate = _county.waterRate ?? 1.0;
        _paybillNumber = _county.paybillNumber ?? '';
        _tillNumber = _county.tillNumber ?? '';

        debugPrint('County loaded: ${_county.name}');
        debugPrint('Water rate: $_waterRate');
      } else {
        debugPrint('County not found for code: ${widget.countyCode}');
        throw Exception('County not found');
      }
    } catch (e) {
      // Use defaults
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

    // Load payment methods
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

    // Initialize payment service
    _updatePaymentService();

    _initializeForm();
    _testServerConnection();
  }

  void _initializeForm() {
    if (widget.meterNumber.isNotEmpty) {
      meterNumberController.text = widget.meterNumber;
    }
    _loadUserPhoneNumber();
  }

  void _updatePaymentService() {
    try {
      _paymentService = CountyPaymentFactory.getService(
        widget.countyCode,
        _selectedPaymentMethod,
      );
    } catch (e) {
      debugPrint('Error creating payment service: $e');
      // Create a mock service or handle appropriately
      throw Exception('Unable to initialize payment service: $e');
    }
  }

  Future<void> _loadUserPhoneNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final phone = data['phone']?.toString() ?? '';
        if (phone.isNotEmpty) {
          phoneController.text = phone;
        }
      }
    } catch (e) {
      debugPrint('Phone Load Error: $e');
    }
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

  void _resetForm() {
    setState(() {
      _paymentCompleted = false;
      _paymentReference = null;
      _paymentStatus = 'pending';
      _litresPurchased = 0.0;
      _litresToPurchase = 0.0;
    });
    amountController.clear();
  }

  // Update amount controller to calculate litres
  void _updateLitresCalculation(String amountText) {
    final amount = double.tryParse(amountText) ?? 0.0;
    setState(() {
      _litresToPurchase = _county.calculateLitres(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
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
                    _county.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),

          // County Info Card
          _buildCountyInfoCard(),

          // Water Rate Info
          _buildWaterRateInfo(),

          // Server Status
          if (!_serverConnected)
            Container(
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
                      "${_county.name} payment server not connected. Payments may fail.",
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
            ),

          // Payment Method Selector
          if (_paymentMethods.isNotEmpty) _buildPaymentMethodSelector(),

          const SizedBox(height: 16),

          // Payment Form
          Container(
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
                  hintText: 'e.g. 10, 50, 100, 500, 1000',
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
                // Info message
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
                      backgroundColor: _serverConnected &&
                              _isPhoneValid() &&
                              _isAmountValid()
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
                              Text(
                                'PROCEED TO PAY',
                                style: const TextStyle(
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
          ),
        ],
      ),
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
                  image: _county.countyLogo != null &&
                          _county.countyLogo!.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(_county.countyLogo!),
                          fit: BoxFit.cover,
                          onError: (error, stackTrace) {
                            // Error handled by container color
                          },
                        )
                      : null,
                ),
                child: _county.countyLogo == null || _county.countyLogo!.isEmpty
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
                      _county.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      _county.waterProvider,
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
          if (_county.customerCare != null && _county.customerCare!.isNotEmpty)
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Customer Care: ${_county.customerCare!}',
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

                  // Update paybill if method-specific
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
                                onError: (error, stackTrace) {
                                  // Error handled by icon
                                },
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

  Widget _buildSuccessScreen() {
    final isFailed = _paymentStatus == 'failed';
    final isPending = _paymentStatus == 'pending';
    final isSuccess = _paymentStatus == 'successful';

    // Auto-redirect for successful payments
    if (isSuccess && mounted && !_redirecting) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _redirectToDashboard();
        }
      });
      _redirecting = true;
    }

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
                      : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFailed
                  ? Icons.error_outline
                  : isPending
                      ? Icons.pending_outlined
                      : Icons.check_circle,
              color: isFailed
                  ? Colors.red
                  : isPending
                      ? Colors.orange
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
                    : 'Payment Successful!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isFailed
                  ? Colors.red
                  : isPending
                      ? Colors.orange
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
            'County: ${_county.name}',
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
          const SizedBox(height: 16),
          Text(
            isPending
                ? 'Please check your phone to complete the payment'
                : isFailed
                    ? 'Please try again or contact support'
                    : 'Your payment has been processed successfully\nRedirecting to dashboard...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Show different buttons based on payment status
          if (isFailed)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _redirectToPaymentScreen(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'TRY AGAIN',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else if (isPending)
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
                    onPressed: () => _redirectToDashboard(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Go to Dashboard'),
                  ),
                ),
              ],
            )
          else // Success - show countdown
            Column(
              children: [
                SizedBox(
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
                      'GO TO DASHBOARD NOW',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Automatically redirecting in 3 seconds...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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

    // Basic validation - allow any 10-13 digit number starting with 0, 1, 7, or +254
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');

    // Check if it's a valid phone number format
    try {
      if (_paymentService.isValidPhone(phone)) {
        return true;
      }
    } catch (e) {
      debugPrint('Phone validation error: $e');
    }

    // Additional flexible validation for user convenience
    final phoneRegex = RegExp(r'^(\+?254|0)?[17][0-9]{8,9}$');
    return phoneRegex.hasMatch(cleaned);
  }

  bool _isAmountValid() {
    final amountText = amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText) ?? 0.0;
    return amount > 0;
  }

  Future<void> _handlePayment() async {
    FocusScope.of(context).unfocus();

    // Check if county is loaded
    try {
      if (_county == null) {
        _showErrorDialog('County configuration not loaded. Please try again.');
        return;
      }
    } catch (e) {
      _showErrorDialog('County information error. Please restart the app.');
      return;
    }

    final phone = phoneController.text.trim();
    final meterNumber = meterNumberController.text.trim();
    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    final litres = _county.calculateLitres(amount);

    // Validation
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

    // Check phone validation
    try {
      if (!_paymentService.isValidPhone(phone)) {
        _showErrorDialog(
            'Please enter a valid phone number for ${_county.name}');
        return;
      }
    } catch (e) {
      _showErrorDialog(
          'Phone validation error. Please check your phone number.');
      return;
    }

    // Confirm payment
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${_county.name} Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: KES ${amount.toStringAsFixed(2)}'),
            Text('Litres: ${litres.toStringAsFixed(2)} litres'),
            Text('Phone: $phone'),
            Text('Meter: $meterNumber'),
            Text('County: ${_county.name}'),
            const SizedBox(height: 16),
            Text(
              'You will receive a payment prompt on your phone to complete the payment.',
              style: const TextStyle(color: Colors.grey),
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
            child: const Text('Confirm'),
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

      // Call county-specific payment service
      final result = await _paymentService.initiatePayment(
        userId: user.uid,
        phone: phone,
        amount: amount,
        meterNumber: meterNumber,
        county: _county,
      );

      // Check if result is valid
      if (result == null) {
        throw Exception('Payment service returned no result');
      }

      // Update water usage after successful payment
      final status = result['status']?.toString() ?? 'pending';
      if (status == 'pending' || status == 'successful') {
        try {
          await _updateWaterUsageAfterPayment(
            meterNumber: meterNumber,
            userId: widget.userId,
            litresPurchased: litres,
            amount: amount,
            county: _county,
          );
        } catch (e) {
          debugPrint('Water usage update error: $e');
        }
      }

      setState(() {
        _paymentCompleted = true;
        _paymentReference = result['reference']?.toString() ?? 'N/A';
        _paymentStatus = status;
        _litresPurchased = litres;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ??
                'Payment request sent to your phone'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Add a delay before redirecting (for user to see success message)
      await Future.delayed(const Duration(seconds: 2));

      // Redirect based on payment status
      if (mounted) {
        if (status == 'successful' || status == 'pending') {
          // Successful or pending payment - redirect to dashboard
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _redirectToDashboard();
            }
          });
        } else {
          // Failed payment - redirect back to payment screen
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _redirectToPaymentScreen();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      if (mounted) {
        _showErrorDialog('Payment failed: ${e.toString()}');
        // Redirect back to payment screen on error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _redirectToPaymentScreen();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _redirectToDashboard() {
    try {
      // Clear any existing routes and go to dashboard
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard', // Replace with your dashboard route name
        (route) => false,
      );
    } catch (e) {
      debugPrint('Redirect to dashboard error: $e');
      Navigator.pop(context); // Fallback to pop
    }
  }

  void _redirectToPaymentScreen() {
    // Go back to payment screen but keep the form data
    setState(() {
      _paymentCompleted = false;
      _paymentStatus = 'pending';
      _redirecting = false;
    });
  }

  void _navigateBack() {
    try {
      // If payment is completed and successful/pending, go to dashboard
      if (_paymentCompleted &&
          (_paymentStatus == 'successful' || _paymentStatus == 'pending')) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      } else {
        // Otherwise, go back normally
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Navigate back error: $e');
      Navigator.pop(context); // Fallback
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
      debugPrint('• County: ${county.name}');
      debugPrint('• User ID: $userId');
      debugPrint('• Meter: $meterNumber');
      debugPrint('• Litres Purchased: $litresPurchased');
      debugPrint('• Amount: $amount');

      // Get current water usage data
      final waterUsageDoc =
          await firestore.collection('waterUsage').doc(meterNumber).get();

      if (waterUsageDoc.exists && waterUsageDoc.data() != null) {
        final currentData = waterUsageDoc.data()!;

        // Calculate new values
        double currentReading =
            (currentData['currentReading'] ?? 0.0).toDouble();
        double remainingUnits =
            (currentData['remainingUnits'] ?? 0.0).toDouble();
        double totalUnitsPurchased =
            (currentData['totalUnitsPurchased'] ?? 0.0).toDouble();

        // Add purchased litres
        double newCurrentReading = currentReading + litresPurchased;
        double newRemainingUnits = remainingUnits + litresPurchased;
        double newTotalPurchased = totalUnitsPurchased + litresPurchased;

        debugPrint('📈 Updating water usage:');
        debugPrint('   - Old currentReading: $currentReading');
        debugPrint('   - Old remainingUnits: $remainingUnits');
        debugPrint('   - Old totalPurchased: $totalUnitsPurchased');
        debugPrint('   - New currentReading: $newCurrentReading');
        debugPrint('   - New remainingUnits: $newRemainingUnits');
        debugPrint('   - New totalPurchased: $newTotalPurchased');

        // Update waterUsage collection
        await firestore.collection('waterUsage').doc(meterNumber).update({
          'currentReading': newCurrentReading,
          'remainingUnits': newRemainingUnits,
          'totalUnitsPurchased': newTotalPurchased,
          'countyCode': county.code,
          'countyName': county.name,
          'waterRate': county.waterRate,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update clients collection
        await firestore.collection('clients').doc(meterNumber).update({
          'remainingLitres': newRemainingUnits,
          'totalLitresPurchased': newTotalPurchased,
          'county': county.code,
          'lastTopUp': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update dashboard_data
        await firestore.collection('dashboard_data').doc(userId).set({
          'remainingBalance': newRemainingUnits,
          'totalPurchased': newTotalPurchased,
          'meterNumber': meterNumber,
          'countyCode': county.code,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ Water usage updated successfully');
      } else {
        // Create new water usage document
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
            Text(
              'Payment Error',
              style: TextStyle(color: _primaryColor),
            ),
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

  @override
  void dispose() {
    phoneController.dispose();
    meterNumberController.dispose();
    amountController.dispose();
    super.dispose();
  }
}

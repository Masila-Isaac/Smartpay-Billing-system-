import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mpesa_service.dart';

class PayBillScreen extends StatefulWidget {
  final String meterNumber;

  const PayBillScreen({super.key, required this.meterNumber});

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

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _testServerConnection();
  }

  void _initializeForm() {
    if (widget.meterNumber.isNotEmpty) {
      meterNumberController.text = widget.meterNumber;
    }
    _loadUserPhoneNumber();
  }

  Future<void> _loadUserPhoneNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final phone = userDoc.data()?['phone']?.toString() ?? '';
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
      final connected = await MpesaService.testConnection();
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
    });
    amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _paymentCompleted ? 'Payment Status' : 'Pay Water Bill',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
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
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.water_drop, color: Colors.blue, size: 40),
              ),
              const SizedBox(width: 12),
              const Text(
                'SmartPay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

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
                      "Server not connected. Payments may fail.",
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: _testServerConnection,
                    child: const Text("RETRY"),
                  ),
                ],
              ),
            ),

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
                _buildInfoCard('Paybill Number', '123456'),
                const SizedBox(height: 16),
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
                  hintText: 'e.g. 1, 10, 50, 100, 1000',
                  icon: Icons.attach_money_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Phone Number',
                  controller: phoneController,
                  hintText: '07XXXXXXXX',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                // Info message about any amount
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Any amount accepted - 1 KES = 1 litre of water",
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
                      backgroundColor: _serverConnected
                          ? const Color(0xff006ee6)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _serverConnected && !_isLoading ? _handlePayment : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 20),
                              SizedBox(width: 8),
                              Text(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final isFailed = _paymentStatus == 'failed';
    final isPending = _paymentStatus == 'pending';

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
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
            'Water Purchased: ${amountController.text} litres',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_paymentReference != null && _paymentReference != 'N/A') ...[
            const SizedBox(height: 16),
            Text(
              'Reference: $_paymentReference',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            isPending
                ? 'Please check your phone to complete the payment'
                : isFailed
                    ? 'Please try again or contact support'
                    : 'Your payment has been processed successfully',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Make Another Payment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back to Dashboard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
              fontSize: 16,
            ),
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
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _handlePayment() async {
    FocusScope.of(context).unfocus();

    final phone = phoneController.text.trim();
    final meterNumber = meterNumberController.text.trim();
    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    // Validation - REMOVED THE 10 KES MINIMUM
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

    // Phone number validation and formatting
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '254${phone.substring(1)}';
    } else if ((phone.startsWith('7') || phone.startsWith('1')) &&
        phone.length == 9) {
      formattedPhone = '254$phone';
    }

    if (!RegExp(r'^254(7|1)\d{8}$').hasMatch(formattedPhone)) {
      _showErrorDialog('Please enter a valid Safaricom phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Please log in to make payments");
      }

      // Call M-Pesa service
      final result = await MpesaService.initiatePayment(
        userId: user.uid,
        phone: formattedPhone,
        amount: amount,
        meterNumber: meterNumber,
      );

      setState(() {
        _paymentCompleted = true;
        _paymentReference = result['reference'] ?? 'N/A';
        _paymentStatus = result['status'] ?? 'pending';
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result['message'] ?? 'Payment initiated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      if (mounted) {
        _showErrorDialog('Payment failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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

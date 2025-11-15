import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mpesa_service.dart';

class PayBillScreen extends StatefulWidget {
  const PayBillScreen({super.key});

  @override
  State<PayBillScreen> createState() => _PayBillScreenState();
}

class _PayBillScreenState extends State<PayBillScreen> {
  final phoneController = TextEditingController();
  final accountNumberController = TextEditingController();
  final amountController = TextEditingController();
  String accountType = 'Personal';
  bool _isLoading = false;
  bool _serverConnected = true;

  @override
  void initState() {
    super.initState();
    _testServerConnection();
  }

  Future<void> _testServerConnection() async {
    final connected = await MpesaService.testConnection();
    setState(() {
      _serverConnected = connected;
    });

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "⚠️ Cannot connect to server. Please check if backend is running."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Water Bill'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Server status indicator
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
                        "Server not connected",
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

            // Payment form
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText:
                            'Phone Number (e.g. 07xxxxxxxx or 2547xxxxxxxx)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        prefixIcon: Icon(Icons.account_circle),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (KES)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField(
                      value: accountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        prefixIcon: Icon(Icons.business_center),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Personal',
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                          value: 'Business',
                          child: Text('Business'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => accountType = value!),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Processing payment...'),
                            ],
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _serverConnected
                                  ? Colors.blueAccent
                                  : Colors.grey,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: _serverConnected ? _handlePayment : null,
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                  ],
                ),
              ),
            ),

            // Info section
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Use Safaricom number (07... or 2547...)'),
                    Text('• Ensure sufficient M-Pesa balance'),
                    Text('• You will receive an STK push prompt'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    FocusScope.of(context).unfocus();

    final phone = phoneController.text.trim();
    final account = accountNumberController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

    if (phone.isEmpty || account.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields correctly."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Format phone number to 254XXXXXXXXX
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '254${phone.substring(1)}';
    } else if ((phone.startsWith('7') || phone.startsWith('1')) &&
        phone.length == 9) {
      formattedPhone = '254$phone';
    } else if (!phone.startsWith('254')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Enter a valid Kenyan number (07..., 01..., or 2547...)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!RegExp(r'^254(7|1)\d{8}$').hasMatch(formattedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Safaricom number format"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You must be logged in to make a payment."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final message = await MpesaService.initiatePayment(
        userId: user.uid,
        phone: formattedPhone,
        amount: amount,
        accountRef: account,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? "Payment initiated successfully."),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      phoneController.clear();
      accountNumberController.clear();
      amountController.clear();
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment failed: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    accountNumberController.dispose();
    amountController.dispose();
    super.dispose();
  }
}

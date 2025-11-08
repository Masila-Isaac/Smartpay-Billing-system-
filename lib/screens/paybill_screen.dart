import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Water Bill')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (e.g. 07xxxxxxxx or 2547xxxxxxxx)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: accountNumberController,
                  decoration:
                      const InputDecoration(labelText: 'Account Number'),
                ),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (KES)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField(
                  value: accountType,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Personal', child: Text('Personal')),
                    DropdownMenuItem(
                        value: 'Business', child: Text('Business')),
                  ],
                  onChanged: (value) => setState(() => accountType = value!),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _handlePayment,
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Updated Payment Handler with Full Phone Validation
  Future<void> _handlePayment() async {
    final phone = phoneController.text.trim();
    final account = accountNumberController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

    if (phone.isEmpty || account.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields correctly.")),
      );
      return;
    }

    String formattedPhone = phone;

    // ✅ Format the number to Safaricom standard 254XXXXXXXXX
    if (phone.startsWith('0')) {
      formattedPhone = '254${phone.substring(1)}';
    } else if (phone.startsWith('7') && phone.length == 9) {
      formattedPhone = '254$phone';
    } else if (phone.startsWith('1') && phone.length == 9) {
      formattedPhone = '254$phone';
    } else if (!phone.startsWith('254')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Enter a valid Kenyan number (07..., 01..., or 2547...)"),
        ),
      );
      return;
    }

    // ✅ Validate final Safaricom format
    if (!RegExp(r'^254(7|1)\d{8}$').hasMatch(formattedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Safaricom number format")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final message = await MpesaService.initiatePayment(
        phone: formattedPhone, // ✅ Use formatted version
        amount: amount,
        accountRef: account,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? "Payment initiated successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

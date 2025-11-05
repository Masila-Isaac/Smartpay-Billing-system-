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
                      labelText: 'Phone Number (e.g. 254712345678)'),
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
                        child: const Text('Pay Now',
                            style: TextStyle(fontSize: 18)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

    if (!RegExp(r'^2547\d{8}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Enter valid Safaricom number (e.g. 254712345678)")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final message = await MpesaService.initiatePayment(
        phone: phone,
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

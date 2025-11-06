import 'package:flutter/material.dart';

class MpesaDetailsForm extends StatefulWidget {
  const MpesaDetailsForm({super.key});

  @override
  _MpesaDetailsFormState createState() => _MpesaDetailsFormState();
}

class _MpesaDetailsFormState extends State<MpesaDetailsForm> {
  final phoneController = TextEditingController();
  final accountNumberController = TextEditingController();
  final accountTypeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            TextFormField(
              controller: accountNumberController,
              decoration: const InputDecoration(labelText: 'Account Number'),
            ),
            DropdownButtonFormField(
              initialValue: accountTypeController.text,
              onChanged: (value) {
                accountTypeController.text = value!;
              },
              items: [
                'Personal',
                'Business',
              ].map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Send M-Pesa payment request
              },
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String phone;
  final double amount;
  final String accountRef;
  final String status;
  final String transactionId;
  final DateTime timestamp;

  Payment({
    required this.id,
    required this.phone,
    required this.amount,
    required this.accountRef,
    required this.status,
    required this.transactionId,
    required this.timestamp,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Payment(
      id: doc.id,
      phone: data['phone'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      accountRef: data['accountRef'] ?? '',
      status: data['status'] ?? 'Pending',
      transactionId: data['transactionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'amount': amount,
      'accountRef': accountRef,
      'status': status,
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
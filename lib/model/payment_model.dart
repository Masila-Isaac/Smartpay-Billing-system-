// lib/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String userId;
  final String phone;
  final double amount;
  final String accountRef;
  final String status;
  final String transactionId;
  final DateTime timestamp;
  final double unitsPurchased;
  final bool processed;
  final double? conversionRate;

  Payment({
    required this.id,
    required this.userId,
    required this.phone,
    required this.amount,
    required this.accountRef,
    required this.status,
    required this.transactionId,
    required this.timestamp,
    this.unitsPurchased = 0,
    this.processed = false,
    this.conversionRate,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Payment(
      id: doc.id,
      userId: data['userId'] ?? '',
      phone: data['phone'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      accountRef: data['accountRef'] ?? '',
      status: data['status'] ?? 'Pending',
      transactionId: data['transactionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      unitsPurchased: (data['unitsPurchased'] ?? 0).toDouble(),
      processed: data['processed'] ?? false,
      conversionRate: data['conversionRate']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phone': phone,
      'amount': amount,
      'accountRef': accountRef,
      'status': status,
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
      'unitsPurchased': unitsPurchased,
      'processed': processed,
      if (conversionRate != null) 'conversionRate': conversionRate,
    };
  }

  // Helper methods
  bool get isSuccessful => status == 'Success';
  bool get isProcessed => processed;
  String get formattedAmount => 'KES ${amount.toStringAsFixed(2)}';
  String get formattedUnits => '${unitsPurchased.toStringAsFixed(2)} L';
}

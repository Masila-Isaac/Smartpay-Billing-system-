// lib/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String userId;
  final String phone;
  final double amount;
  final String meterNumber;
  final String status;
  final String transactionId;
  final DateTime timestamp;
  final double unitsPurchased;
  final bool processed;
  final double? conversionRate;
  final String? reference;

  Payment({
    required this.id,
    required this.userId,
    required this.phone,
    required this.amount,
    required this.meterNumber,
    required this.status,
    required this.transactionId,
    required this.timestamp,
    this.unitsPurchased = 0,
    this.processed = false,
    this.conversionRate,
    this.reference,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Payment(
      id: doc.id,
      userId: data['userId'] ?? '',
      phone: data['phone'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      meterNumber: data['meterNumber'] ?? '', // FIXED: was 'meteterNumber'
      status: data['status'] ?? 'Pending',
      transactionId: data['transactionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      unitsPurchased: (data['unitsPurchased'] ?? 0).toDouble(),
      processed: data['processed'] ?? false,
      conversionRate: data['conversionRate']?.toDouble(),
      reference: data['reference'], // ADDED: reference field
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phone': phone,
      'amount': amount,
      'meterNumber': meterNumber, // FIXED: was 'meteterNumber'
      'status': status,
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
      'unitsPurchased': unitsPurchased,
      'processed': processed,
      if (conversionRate != null) 'conversionRate': conversionRate,
      if (reference != null) 'reference': reference, // ADDED: reference field
    };
  }

  // Helper methods
  bool get isSuccessful =>
      status.toLowerCase() == 'success' || status.toLowerCase() == 'completed';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isFailed => status.toLowerCase() == 'failed';
  bool get isProcessed => processed;
  String get formattedAmount => 'KES ${amount.toStringAsFixed(2)}';
  String get formattedUnits => '${unitsPurchased.toStringAsFixed(2)} L';

  // Copy with method for updates
  Payment copyWith({
    String? id,
    String? userId,
    String? phone,
    double? amount,
    String? meterNumber,
    String? status,
    String? transactionId,
    DateTime? timestamp,
    double? unitsPurchased,
    bool? processed,
    double? conversionRate,
    String? reference,
  }) {
    return Payment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      amount: amount ?? this.amount,
      meterNumber: meterNumber ?? this.meterNumber,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      timestamp: timestamp ?? this.timestamp,
      unitsPurchased: unitsPurchased ?? this.unitsPurchased,
      processed: processed ?? this.processed,
      conversionRate: conversionRate ?? this.conversionRate,
      reference: reference ?? this.reference,
    );
  }
}

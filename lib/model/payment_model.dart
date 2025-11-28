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
  final String? error; // ADDED: error field
  final DateTime? updatedAt;
  final String? mpesaReceiptNumber;

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
    this.error, // ADDED: error field
    this.updatedAt,
    this.mpesaReceiptNumber,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Payment(
      id: doc.id,
      userId: data['userId'] ?? '',
      phone: data['phone'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      meterNumber: data['meterNumber'] ?? '',
      status: data['status'] ?? 'Pending',
      transactionId: data['transactionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      unitsPurchased: (data['unitsPurchased'] ?? 0).toDouble(),
      processed: data['processed'] ?? false,
      conversionRate: data['conversionRate']?.toDouble(),
      reference: data['reference'],
      error: data['error'], // ADDED: error field
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      mpesaReceiptNumber: data['mpesaReceiptNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phone': phone,
      'amount': amount,
      'meterNumber': meterNumber,
      'status': status,
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
      'unitsPurchased': unitsPurchased,
      'processed': processed,
      if (conversionRate != null) 'conversionRate': conversionRate,
      if (reference != null) 'reference': reference,
      if (error != null) 'error': error, // ADDED: error field
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (mpesaReceiptNumber != null) 'mpesaReceiptNumber': mpesaReceiptNumber,
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
    String? error, // ADDED: error field
    DateTime? updatedAt,
    String? mpesaReceiptNumber,
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
      error: error ?? this.error, // ADDED: error field
      updatedAt: updatedAt ?? this.updatedAt,
      mpesaReceiptNumber: mpesaReceiptNumber ?? this.mpesaReceiptNumber,
    );
  }

  @override
  String toString() {
    return 'Payment('
        'id: $id, '
        'userId: $userId, '
        'phone: $phone, '
        'amount: $amount, '
        'meterNumber: $meterNumber, '
        'status: $status, '
        'transactionId: $transactionId, '
        'timestamp: $timestamp, '
        'unitsPurchased: $unitsPurchased, '
        'processed: $processed, '
        'conversionRate: $conversionRate, '
        'reference: $reference, '
        'error: $error, ' // ADDED: error in toString
        'updatedAt: $updatedAt, '
        'mpesaReceiptNumber: $mpesaReceiptNumber'
        ')';
  }
}

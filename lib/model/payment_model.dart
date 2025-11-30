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
  final double litresPurchased;
  final bool processed;
  final double? conversionRate;
  final String? reference;
  final String? error;
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
    this.litresPurchased = 0,
    this.processed = false,
    this.conversionRate,
    this.reference,
    this.error,
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
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      litresPurchased: (data['litresPurchased'] ?? 0).toDouble(),
      processed: data['processed'] ?? false,
      conversionRate: data['conversionRate']?.toDouble(),
      reference: data['reference'],
      error: data['error'],
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      mpesaReceiptNumber: data['mpesaReceiptNumber'],
    );
  }

  // ADDED: Factory method for QueryDocumentSnapshot
  factory Payment.fromQueryDoc(QueryDocumentSnapshot doc) {
    return Payment.fromFirestore(doc);
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
      'litresPurchased': litresPurchased,
      'processed': processed,
      if (conversionRate != null) 'conversionRate': conversionRate,
      if (reference != null) 'reference': reference,
      if (error != null) 'error': error,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (mpesaReceiptNumber != null) 'mpesaReceiptNumber': mpesaReceiptNumber,
    };
  }

  // IMPROVED: Helper methods with better status checking
  bool get isSuccessful =>
      status.toLowerCase() == 'success' ||
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'successful';

  bool get isPending =>
      status.toLowerCase() == 'pending' || status.toLowerCase() == 'processing';

  bool get isFailed =>
      status.toLowerCase() == 'failed' ||
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'rejected';

  bool get isProcessed => processed;

  String get formattedAmount => 'KES ${amount.toStringAsFixed(2)}';
  String get formattedUnits => '${litresPurchased.toStringAsFixed(2)} L';

  // ADDED: Formatted date for display
  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  // ADDED: Formatted time for display
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

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
    String? error,
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
      litresPurchased: litresPurchased ?? this.litresPurchased,
      processed: processed ?? this.processed,
      conversionRate: conversionRate ?? this.conversionRate,
      reference: reference ?? this.reference,
      error: error ?? this.error,
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
        'litresPurchased: $litresPurchased, '
        'processed: $processed, '
        'conversionRate: $conversionRate, '
        'reference: $reference, '
        'error: $error, '
        'updatedAt: $updatedAt, '
        'mpesaReceiptNumber: $mpesaReceiptNumber'
        ')';
  }
}

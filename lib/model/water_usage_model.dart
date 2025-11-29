import 'package:cloud_firestore/cloud_firestore.dart';

class WaterUsage {
  final String id;
  final String meterNumber;
  final String userId;
  final String phone;
  final double waterUsed;
  final double remainingUnits;
  final double totalUnitsPurchased;
  final DateTime timestamp;
  final DateTime lastUpdated;
  final String status;

  WaterUsage({
    required this.id,
    required this.meterNumber,
    required this.userId,
    required this.phone,
    required this.waterUsed,
    required this.remainingUnits,
    required this.totalUnitsPurchased,
    required this.timestamp,
    required this.lastUpdated,
    required this.status,
  });

  factory WaterUsage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return WaterUsage(
      id: doc.id,
      meterNumber: data['meterNumber'] ?? doc.id, // Use doc.id as fallback
      userId: data['userId'] ?? '',
      phone: data['phone'] ?? '',
      waterUsed: (data['waterUsed'] ?? 0).toDouble(),
      remainingUnits: (data['remainingUnits'] ?? 0).toDouble(),
      totalUnitsPurchased: (data['totalUnitsPurchased'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
    );
  }

  // ADDED: Factory method for QueryDocumentSnapshot
  factory WaterUsage.fromQueryDoc(QueryDocumentSnapshot doc) {
    return WaterUsage.fromFirestore(doc);
  }

  Map<String, dynamic> toMap() {
    return {
      'meterNumber': meterNumber,
      'userId': userId,
      'phone': phone,
      'waterUsed': waterUsed,
      'remainingUnits': remainingUnits,
      'totalUnitsPurchased': totalUnitsPurchased,
      'timestamp': Timestamp.fromDate(timestamp),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'status': status,
    };
  }

  // Helper methods
  bool get isActive => status.toLowerCase() == 'active';
  bool get isWarning => status.toLowerCase() == 'warning';
  bool get isDepleted => status.toLowerCase() == 'depleted';
  bool get isCritical => remainingUnits < 10; // Less than 10 units

  double get usagePercentage {
    if (totalUnitsPurchased == 0) return 0;
    return (waterUsed / totalUnitsPurchased) * 100;
  }

  double get remainingPercentage {
    if (totalUnitsPurchased == 0) return 0;
    return (remainingUnits / totalUnitsPurchased) * 100;
  }

  String get formattedRemaining => '${remainingUnits.toStringAsFixed(2)} L';
  String get formattedUsed => '${waterUsed.toStringAsFixed(2)} L';
  String get formattedTotal => '${totalUnitsPurchased.toStringAsFixed(2)} L';

  String get formattedRemainingM3 =>
      '${(remainingUnits / 1000).toStringAsFixed(2)} m³';
  String get formattedUsedM3 => '${(waterUsed / 1000).toStringAsFixed(2)} m³';

  // ADDED: Formatted dates for display
  String get formattedLastUpdated {
    return '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year}';
  }

  // ADDED: Copy with method for updates
  WaterUsage copyWith({
    String? id,
    String? meterNumber,
    String? userId,
    String? phone,
    double? waterUsed,
    double? remainingUnits,
    double? totalUnitsPurchased,
    DateTime? timestamp,
    DateTime? lastUpdated,
    String? status,
  }) {
    return WaterUsage(
      id: id ?? this.id,
      meterNumber: meterNumber ?? this.meterNumber,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      waterUsed: waterUsed ?? this.waterUsed,
      remainingUnits: remainingUnits ?? this.remainingUnits,
      totalUnitsPurchased: totalUnitsPurchased ?? this.totalUnitsPurchased,
      timestamp: timestamp ?? this.timestamp,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'WaterUsage('
        'id: $id, '
        'meterNumber: $meterNumber, '
        'userId: $userId, '
        'phone: $phone, '
        'waterUsed: $waterUsed, '
        'remainingUnits: $remainingUnits, '
        'totalUnitsPurchased: $totalUnitsPurchased, '
        'timestamp: $timestamp, '
        'lastUpdated: $lastUpdated, '
        'status: $status'
        ')';
  }
}

// lib/models/water_usage_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WaterUsage {
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
      meterNumber: doc.id,
      userId: data['userId'] ?? '',
      phone: data['phone'] ?? '',
      waterUsed: (data['waterUsed'] ?? 0).toDouble(),
      remainingUnits: (data['remainingUnits'] ?? 0).toDouble(),
      totalUnitsPurchased: (data['totalUnitsPurchased'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
  bool get isActive => status == 'active';
  bool get isWarning => status == 'warning';
  bool get isDepleted => status == 'depleted';

  double get usagePercentage {
    if (totalUnitsPurchased == 0) return 0;
    return (waterUsed / totalUnitsPurchased) * 100;
  }

  String get formattedRemaining => '${remainingUnits.toStringAsFixed(2)} L';
  String get formattedUsed => '${waterUsed.toStringAsFixed(2)} L';
  String get formattedTotal => '${totalUnitsPurchased.toStringAsFixed(2)} L';
}

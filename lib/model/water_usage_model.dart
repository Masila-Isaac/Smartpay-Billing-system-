import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class WaterUsage {
  final String id;
  final String meterNumber;
  final String userId;
  final String phone;
  double waterUsed; // Made non-final so it can be updated
  double remainingUnits;
  double totalUnitsPurchased;
  final DateTime timestamp;
  DateTime lastUpdated;
  String status;

  // Realtime Database reference
  static final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

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

  // Factory constructor for creating from Firestore
  factory WaterUsage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return WaterUsage(
      id: doc.id,
      meterNumber: data['meterNumber'] ?? doc.id,
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

  // Factory method for QueryDocumentSnapshot
  factory WaterUsage.fromQueryDoc(QueryDocumentSnapshot doc) {
    return WaterUsage.fromFirestore(doc);
  }

  // ========== NEW METHODS FOR REALTIME DATABASE ==========

  /// Fetch current water consumption from Realtime Database
  static Future<double> getRealTimeWaterUsed(String meterNumber) async {
    try {
      // Assuming microcontroller sends data to path: /water_readings/{meterNumber}/consumption
      // You can adjust this path based on how your microcontroller sends data
      DatabaseReference ref =
          _rtdb.child('water_readings').child(meterNumber).child('consumption');

      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists) {
        // Convert the value to double (assuming it's sent as number)
        return double.tryParse(snapshot.value.toString()) ?? 0.0;
      }

      return 0.0;
    } catch (e) {
      print('Error fetching real-time water usage: $e');
      return 0.0;
    }
  }

  /// Listen to real-time updates from microcontroller
  static Stream<double> listenToRealTimeWaterUsed(String meterNumber) {
    // This will give you live updates whenever microcontroller sends new data
    return _rtdb
        .child('water_readings')
        .child(meterNumber)
        .child('consumption')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      }
      return 0.0;
    });
  }

  /// Get water rate from Realtime Database
  static Future<double> getWaterRate(String countyCode) async {
    try {
      // Assuming water rates are stored in Realtime DB at: /water_rates/{countyCode}
      DatabaseReference ref = _rtdb.child('water_rates').child(countyCode);

      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists) {
        return double.tryParse(snapshot.value.toString()) ?? 1.0;
      }

      return 1.0; // Default rate
    } catch (e) {
      print('Error fetching water rate: $e');
      return 1.0;
    }
  }

  /// Update water usage based on real-time data
  Future<void> updateFromRealTimeData() async {
    try {
      // Get current consumption from microcontroller
      double currentConsumption = await getRealTimeWaterUsed(meterNumber);

      // If consumption is greater than what we have recorded, update it
      if (currentConsumption > waterUsed) {
        double newlyUsed = currentConsumption - waterUsed;

        // Update the object
        waterUsed = currentConsumption;
        remainingUnits = remainingUnits - newlyUsed;
        lastUpdated = DateTime.now();

        // Update status based on remaining units
        if (remainingUnits <= 0) {
          status = 'depleted';
        } else if (remainingUnits < 10) {
          status = 'warning';
        } else {
          status = 'active';
        }

        // Save the updated data back to Firestore
        await saveToFirestore();
      }
    } catch (e) {
      print('Error updating from real-time data: $e');
    }
  }

  /// Save current data to Firestore
  Future<void> saveToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('waterUsage')
          .doc(meterNumber)
          .update(toMap());
    } catch (e) {
      print('Error saving to Firestore: $e');
    }
  }

  // ========== EXISTING METHODS (Keep all your original methods) ==========

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

  // Formatted dates for display
  String get formattedLastUpdated {
    return '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year}';
  }

  // Copy with method for updates
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../model/water_usage_model.dart';
import '../model/payment_model.dart';

class WaterReadingScreen extends StatefulWidget {
  final String meterNumber;

  const WaterReadingScreen({Key? key, required this.meterNumber})
      : super(key: key);

  @override
  _WaterReadingScreenState createState() => _WaterReadingScreenState();
}

class _WaterReadingScreenState extends State<WaterReadingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late StreamSubscription<DocumentSnapshot> _waterUsageSubscription;
  Map<String, dynamic>? _waterUsage;
  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _startListeningToWaterUsage();
    _loadPaymentHistory();
  }

  void _startListeningToWaterUsage() {
    _waterUsageSubscription = _firestore
        .collection('waterUsage')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          _waterUsage = snapshot.data() as Map<String, dynamic>;
        });
      }
    });
  }

  void _loadPaymentHistory() async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('accountRef', isEqualTo: widget.meterNumber)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        _paymentHistory = querySnapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
      });
    } catch (e) {
      print('Error loading payment history: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'depleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _waterUsageSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Water Usage - ${widget.meterNumber}'),
        backgroundColor: Colors.blue,
      ),
      body: _waterUsage == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Status Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                      _waterUsage!['status'] ?? 'active'),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (_waterUsage!['status'] ?? 'active')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricCard(
                                'Remaining',
                                '${(_waterUsage!['remainingUnits'] ?? 0).toStringAsFixed(2)} L',
                                Colors.blue,
                              ),
                              _buildMetricCard(
                                'Used',
                                '${(_waterUsage!['waterUsed'] ?? 0).toStringAsFixed(2)} L',
                                Colors.orange,
                              ),
                              _buildMetricCard(
                                'Total',
                                '${(_waterUsage!['totalUnitsPurchased'] ?? 0).toStringAsFixed(2)} L',
                                Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Payment History
                  Text(
                    'Recent Payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _paymentHistory.isEmpty
                        ? Center(child: Text('No payment history'))
                        : ListView.builder(
                            itemCount: _paymentHistory.length,
                            itemBuilder: (context, index) {
                              final payment = _paymentHistory[index];
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    payment['status'] == 'Success'
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    color: payment['status'] == 'Success'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  title: Text(
                                    'KES ${payment['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Units: ${payment['unitsPurchased']?.toStringAsFixed(2) ?? '0'} L',
                                  ),
                                  trailing: Text(
                                    payment['status'] ?? 'Pending',
                                    style: TextStyle(
                                      color: payment['status'] == 'Success'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

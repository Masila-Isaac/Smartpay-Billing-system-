import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class WaterReadingScreentrail extends StatefulWidget {
  final String meterNumber;

  const WaterReadingScreentrail({super.key, required this.meterNumber});

  @override
  State<WaterReadingScreentrail> createState() => _WaterReadingScreenState();
}

class _WaterReadingScreenState extends State<WaterReadingScreentrail> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _waterUsageSubscription;
  Map<String, dynamic>? _waterUsage;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    try {
      await _startListeningToWaterUsage();
      await _loadPaymentHistory();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startListeningToWaterUsage() async {
    _waterUsageSubscription = _firestore
        .collection('waterUsage')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        setState(() {
          _waterUsage = snapshot.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _waterUsage = null;
          _isLoading = false;
          _errorMessage = 'No water usage data found for this meter number';
        });
      }
    }, onError: (error) {
      setState(() {
        _errorMessage = 'Error listening to water usage: $error';
        _isLoading = false;
      });
    });
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('accountRef', isEqualTo: widget.meterNumber)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        _paymentHistory = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'timestamp': data['timestamp']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading payment history: $e');
      // Don't set error state for payment history as it's secondary data
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'depleted':
        return Colors.red;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatCurrency(double amount) {
    return 'KES ${amount.toStringAsFixed(2)}';
  }

  String _formatUnits(double units) {
    return '${units.toStringAsFixed(2)} L';
  }

  Widget _buildMetricCard(
      String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryItem(Map<String, dynamic> payment) {
    final isSuccess = payment['status']?.toString().toLowerCase() == 'success';
    final amount = payment['amount'] is double
        ? payment['amount'] as double
        : double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
    final units = payment['unitsPurchased'] is double
        ? payment['unitsPurchased'] as double
        : double.tryParse(payment['unitsPurchased']?.toString() ?? '0') ?? 0.0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuccess ? Icons.check_circle : Icons.pending_actions,
            color: isSuccess ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          _formatCurrency(amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Units: ${_formatUnits(units)}'),
            if (payment['timestamp'] != null && payment['timestamp'].isNotEmpty)
              Text(
                _formatTimestamp(payment['timestamp']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green.shade100 : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            payment['status']?.toString() ?? 'Pending',
            style: TextStyle(
              color: isSuccess ? Colors.green.shade800 : Colors.orange.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading water usage data...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final status = _waterUsage!['status']?.toString() ?? 'active';
    final remainingUnits = _waterUsage!['remainingUnits'] is double
        ? _waterUsage!['remainingUnits'] as double
        : double.tryParse(_waterUsage!['remainingUnits']?.toString() ?? '0') ??
            0.0;
    final waterUsed = _waterUsage!['waterUsed'] is double
        ? _waterUsage!['waterUsed'] as double
        : double.tryParse(_waterUsage!['waterUsed']?.toString() ?? '0') ?? 0.0;
    final totalUnits = _waterUsage!['totalUnitsPurchased'] is double
        ? _waterUsage!['totalUnitsPurchased'] as double
        : double.tryParse(
                _waterUsage!['totalUnitsPurchased']?.toString() ?? '0') ??
            0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricCard(
                        'Remaining',
                        _formatUnits(remainingUnits),
                        Colors.blue,
                        Icons.water_drop,
                      ),
                      _buildMetricCard(
                        'Used',
                        _formatUnits(waterUsed),
                        Colors.orange,
                        Icons.water_damage,
                      ),
                      _buildMetricCard(
                        'Total',
                        _formatUnits(totalUnits),
                        Colors.green,
                        Icons.inventory_2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Payment History Section
          const Text(
            'Recent Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _paymentHistory.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No payment history',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _paymentHistory.length,
                    itemBuilder: (context, index) {
                      return _buildPaymentHistoryItem(_paymentHistory[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _waterUsageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Water Usage - ${widget.meterNumber}'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _waterUsage == null
                  ? _buildErrorWidget()
                  : _buildContent(),
    );
  }
}

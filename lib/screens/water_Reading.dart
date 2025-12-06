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
    print('Initializing WaterReadingScreen for meter: ${widget.meterNumber}');
    _initializeData();
  }

  void _initializeData() async {
    try {
      print('Starting data initialization...');

      // Check if document exists first
      final doc = await _firestore
          .collection('waterUsage')
          .doc(widget.meterNumber)
          .get();

      print('Document exists check: ${doc.exists}');
      print('Document data: ${doc.data()}');
      print('Document ID: ${doc.id}');

      if (!doc.exists) {
        print('No document found for meter number: ${widget.meterNumber}');
        print('Checking collection path: waterUsage/${widget.meterNumber}');

        // Check if collection exists and list all documents
        final allDocs =
            await _firestore.collection('waterUsage').limit(5).get();
        print('First 5 documents in waterUsage collection:');
        for (var doc in allDocs.docs) {
          print('- ${doc.id}: ${doc.data()}');
        }

        setState(() {
          _errorMessage =
              'No water usage data found for meter number: ${widget.meterNumber}';
          _isLoading = false;
          _waterUsage = null;
        });
        return;
      }

      if (doc.data() == null || doc.data()!.isEmpty) {
        print('Document exists but has no data');
        setState(() {
          _errorMessage = 'Water usage document exists but contains no data';
          _isLoading = false;
          _waterUsage = null;
        });
        return;
      }

      // Document exists and has data, start listening
      await _startListeningToWaterUsage();
      await _loadPaymentHistory();
    } catch (e, stackTrace) {
      print('Error in _initializeData: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _startListeningToWaterUsage() async {
    print('Setting up water usage listener for: ${widget.meterNumber}');

    _waterUsageSubscription = _firestore
        .collection('waterUsage')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      print('Water usage snapshot received:');
      print('- Exists: ${snapshot.exists}');
      print('- Has data: ${snapshot.data() != null}');
      print('- Data: ${snapshot.data()}');

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        print('Successfully loaded water usage data:');
        print('- Status: ${data['status']}');
        print('- Remaining units: ${data['remainingUnits']}');
        print('- Water used: ${data['waterUsed']}');
        print('- Total units: ${data['totalUnitsPurchased']}');

        setState(() {
          _waterUsage = data;
          _isLoading = false;
          _errorMessage = ''; // Clear any previous error
        });
      } else {
        print('No valid data in snapshot');
        setState(() {
          _waterUsage = null;
          _isLoading = false;
          _errorMessage = 'No water usage data found for this meter number';
        });
      }
    }, onError: (error) {
      print('Error in water usage listener: $error');
      print('Error type: ${error.runtimeType}');

      // Check for common Firestore errors
      if (error.toString().contains('permission-denied')) {
        setState(() {
          _errorMessage =
              'Permission denied. Please check Firestore security rules.';
          _isLoading = false;
        });
      } else if (error.toString().contains('not-found')) {
        setState(() {
          _errorMessage = 'Document not found in Firestore.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error loading water usage: $error';
          _isLoading = false;
        });
      }
    });

    print('Water usage listener setup complete');
  }

  Future<void> _loadPaymentHistory() async {
    try {
      print('Loading payment history for meter: ${widget.meterNumber}');

      final querySnapshot = await _firestore
          .collection('payments')
          .where('accountRef', isEqualTo: widget.meterNumber)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      print('Found ${querySnapshot.docs.length} payment records');

      setState(() {
        _paymentHistory = querySnapshot.docs.map((doc) {
          final data = doc.data();
          print('Payment doc: ${doc.id} - $data');
          return {
            'id': doc.id,
            ...data,
            'timestamp': data['timestamp']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e, stackTrace) {
      print('Error loading payment history: $e');
      print('Payment history stack trace: $stackTrace');
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              'MTR${widget.meterNumber}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                children: [
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please ensure:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '1. Meter number is correct\n2. Water usage data exists in Firestore\n3. You have proper permissions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _initializeData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Retry'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    // Add a test document for debugging
                    _createTestDocument();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report, size: 20),
                      SizedBox(width: 8),
                      Text('Debug'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Loading water usage data...',
            style: TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
          // Header with meter number
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Water Meter',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'MTR${widget.meterNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            ),
          ),
          const SizedBox(height: 16),

          // Current Status Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Usage Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
            'Recent Payment History',
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
                          'No payment history found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Payments will appear here',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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

  // Test method for debugging
  Future<void> _createTestDocument() async {
    try {
      print('Creating test document for meter: ${widget.meterNumber}');

      await _firestore.collection('waterUsage').doc(widget.meterNumber).set({
        'status': 'active',
        'remainingUnits': 1500.0,
        'waterUsed': 500.0,
        'totalUnitsPurchased': 2000.0,
        'meterNumber': widget.meterNumber,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Test document created successfully');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test document created for MTR${widget.meterNumber}'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the data
      _initializeData();
    } catch (e) {
      print('Error creating test document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create test document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    print('Disposing WaterReadingScreen for meter: ${widget.meterNumber}');
    _waterUsageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Water Usage - MTR${widget.meterNumber}'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
            tooltip: 'Refresh',
          ),
        ],
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

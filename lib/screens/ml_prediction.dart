import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserPredictionScreen extends StatefulWidget {
  final String userId; // This would be the logged-in user's ID

  const UserPredictionScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserPredictionScreen> createState() => _UserPredictionScreenState();
}

class _UserPredictionScreenState extends State<UserPredictionScreen> {
  late final DocumentReference
      _userPredictionRef; // Changed to DocumentReference

  @override
  void initState() {
    super.initState();
    // This is a document reference, not a collection reference
    _userPredictionRef = FirebaseFirestore.instance
        .collection('ml_predictions')
        .doc(widget.userId); // This returns a DocumentReference
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF), // Fixed color (was missing F)
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userPredictionRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNoDataState();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildPredictionDashboard(data);
        },
      ),
    );
  }

  Widget _buildPredictionDashboard(Map<String, dynamic> data) {
    // Extract only the most important information
    final String riskLevel = data['prediction'] ?? 'Unknown';
    final double probability = (data['probability'] ?? 0).toDouble();
    final double consumption = (data['consumption_litres'] ?? 0).toDouble();
    final double remainingUnits =
        (data['remaining_litres'] ?? data['remainingUnits'] ?? 0).toDouble();
    final double totalLiters =
        (data['total_liters'] ?? data['totalLiters'] ?? 0).toDouble();
    final bool hasLeak = data['hardware_leak'] ?? data['Leak'] ?? false;
    final String metreId = data['metre_id'] ?? 'Not Available';
    final double flowRate = (data['flow_rate_litres_per_sec'] ?? 0).toDouble();

    // Calculate usage percentage
    final double usedPercentage = totalLiters > 0
        ? ((totalLiters - remainingUnits) / totalLiters * 100).clamp(0, 100)
        : 0;

    return CustomScrollView(
      slivers: [
        // Beautiful Header with Greeting
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: Colors.blue,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1976D2),
                    Color(0xFF64B5F6),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'User ${widget.userId.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Meter ID: $metreId',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Main Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Risk Level Card
              _buildRiskCard(riskLevel, probability),

              const SizedBox(height: 20),

              // Water Usage Stats
              _buildWaterUsageCard(
                consumption,
                remainingUnits,
                totalLiters,
                usedPercentage,
              ),

              const SizedBox(height: 20),

              // Alerts Section
              if (hasLeak || riskLevel.toLowerCase() == 'high')
                _buildAlertsCard(hasLeak, riskLevel),

              const SizedBox(height: 20),

              // Real-time Monitoring
              _buildMonitoringCard(flowRate, hasLeak),

              const SizedBox(height: 20),

              // Prediction Details
              _buildPredictionDetailsCard(data),

              const SizedBox(height: 30),

              // Last Updated
              if (data['timestamp'] != null)
                _buildLastUpdated(data['timestamp']),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(String riskLevel, double probability) {
    Color riskColor;
    IconData riskIcon;
    String riskMessage;

    switch (riskLevel.toLowerCase()) {
      case 'high':
        riskColor = Colors.red;
        riskIcon = Icons.warning_amber_rounded;
        riskMessage = 'Immediate attention needed';
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskIcon = Icons.info_outline;
        riskMessage = 'Monitor your usage';
        break;
      default:
        riskColor = Colors.green;
        riskIcon = Icons.check_circle_outline;
        riskMessage = 'All systems normal';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            riskColor,
            riskColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  riskIcon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RISK LEVEL: $riskLevel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        riskMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: probability,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prediction Confidence',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '${(probability * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterUsageCard(
    double consumption,
    double remaining,
    double total,
    double usedPercentage,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Water Usage Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Consumed',
                  '${consumption.toStringAsFixed(1)} L',
                  Icons.opacity,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Remaining',
                  '${remaining.toStringAsFixed(1)} L',
                  Icons.water_drop,
                  Colors.green,
                ),
                _buildStatCard(
                  'Total',
                  '${total.toStringAsFixed(1)} L',
                  Icons.storage,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: usedPercentage / 100,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.lightBlue],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Usage Progress',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '${usedPercentage.toStringAsFixed(1)}% used',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsCard(bool hasLeak, String riskLevel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hasLeak)
              _buildAlertItem(
                Icons.warning,
                Colors.red,
                'Leak Detected!',
                'Immediate inspection required',
              ),
            if (hasLeak && riskLevel.toLowerCase() == 'high')
              const SizedBox(height: 12),
            if (riskLevel.toLowerCase() == 'high')
              _buildAlertItem(
                Icons.analytics,
                Colors.orange,
                'High Risk Alert',
                'Unusual consumption pattern detected',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(
      IconData icon, Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringCard(double flowRate, bool hasLeak) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Real-time Monitoring',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMonitorItem(
                  'Flow Rate',
                  '${flowRate.toStringAsFixed(1)} L/s',
                  Icons.speed,
                  flowRate > 30 ? Colors.red : Colors.green,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                _buildMonitorItem(
                  'Status',
                  hasLeak ? 'Leak' : 'Normal',
                  Icons.circle,
                  hasLeak ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionDetailsCard(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: Colors.deepPurple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Prediction Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Consumption',
              '${(data['consumption_litres'] ?? 0).toStringAsFixed(1)} Liters',
              Icons.water_drop,
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Revenue Forecast',
              '\$${(data['predicted_revenue'] ?? 0).toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            if (data['days_remaining'] != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                'Time Remaining',
                '${(data['days_remaining'] ?? 0).toStringAsFixed(1)} days',
                Icons.timer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdated(dynamic timestamp) {
    String formattedTime = 'Recently';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        formattedTime = 'Just now';
      } else if (difference.inHours < 1) {
        formattedTime = '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        formattedTime = '${difference.inHours} hours ago';
      } else {
        formattedTime = DateFormat('MMM d, yyyy').format(date);
      }
    }

    return Center(
      child: Text(
        'Last updated: $formattedTime',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[200],
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Predictions Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We haven\'t generated any predictions\nfor your account yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

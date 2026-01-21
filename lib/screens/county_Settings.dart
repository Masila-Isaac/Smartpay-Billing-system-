import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartpay/config/counties.dart' show CountyConfig;
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/provider/county_theme_provider.dart';

class CountySettingsScreen extends StatelessWidget {
  const CountySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<CountyThemeProvider>(context);
    final currentCounty = themeProvider.county;

    return Scaffold(
      appBar: AppBar(
        title: const Text('County Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current County Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(currentCounty.countyLogo),
                          fit: BoxFit.cover,
                          onError: (error, stackTrace) => Container(
                            color: themeProvider.primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.location_city,
                              color: themeProvider.primaryColor,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current County',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentCounty.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentCounty.waterProvider,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.attach_money,
                                  size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'KES ${currentCounty.waterRate.toStringAsFixed(2)} per litre',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Change County Section
            const Text(
              'Change County',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your county to update water rates and payment methods',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // County List
            ...CountyConfig.getAllCounties().map((county) {
              final isCurrent = county.code == currentCounty.code;
              return _buildCountyOption(context, county, isCurrent);
            }),

            const SizedBox(height: 32),

            // County Information
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'County Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Paybill Number', currentCounty.paybillNumber),
                    if (currentCounty.tillNumber.isNotEmpty &&
                        currentCounty.tillNumber != 'N/A')
                      _buildInfoRow('Till Number', currentCounty.tillNumber),
                    _buildInfoRow('Customer Care', currentCounty.customerCare),
                    _buildInfoRow(
                        'Water Provider', currentCounty.waterProvider),
                    _buildInfoRow('Water Rate',
                        'KES ${currentCounty.waterRate.toStringAsFixed(2)} per litre'),

                    const SizedBox(height: 16),

                    // Payment Methods
                    const Text(
                      'Available Payment Methods:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currentCounty.paymentMethods.entries
                          .where((entry) => entry.value['enabled'] == true)
                          .map((entry) {
                        return Chip(
                          label: Text(entry.value['name']),
                          backgroundColor:
                              themeProvider.primaryColor.withOpacity(0.1),
                          labelStyle:
                              TextStyle(color: themeProvider.primaryColor),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountyOption(
      BuildContext context, County county, bool isCurrent) {
    final themeProvider = Provider.of<CountyThemeProvider>(context);
    final primaryColor = Color(
        int.parse(county.theme['primaryColor'].replaceFirst('#', '0xFF')));

    return Card(
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? primaryColor : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: AssetImage(county.countyLogo),
              fit: BoxFit.cover,
              onError: (error, stackTrace) => Container(
                color: primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.location_city,
                  color: primaryColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          county.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              county.waterProvider,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.attach_money, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'KES ${county.waterRate.toStringAsFixed(2)}/litre',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isCurrent
            ? Icon(Icons.check_circle, color: primaryColor)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: isCurrent
            ? null
            : () async {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Switch to ${county.name}?'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'You are about to switch to ${county.name} county.'),
                        const SizedBox(height: 8),
                        const Text('This will:'),
                        const SizedBox(height: 8),
                        _buildChangeItem(
                            'Update water rate to KES ${county.waterRate.toStringAsFixed(2)}/litre'),
                        _buildChangeItem(
                            'Change payment methods to ${county.waterProvider}'),
                        _buildChangeItem(
                            'Update app theme to ${county.name} colors'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text('Switch County'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  // Update county
                  await themeProvider.updateCounty(county.code);

                  // Update Firestore
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'county': county.code,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${county.name} county'),
                      backgroundColor: primaryColor,
                    ),
                  );
                }
              },
      ),
    );
  }

  Widget _buildChangeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

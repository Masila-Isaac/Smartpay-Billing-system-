import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_vert, size: 20),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
              const PopupMenuItem(value: 'settings', child: Text('Notification settings')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Today Section
            _buildSectionHeader('Today'),
            const SizedBox(height: 16),

            _buildNotificationItem(
              icon: Icons.payment,
              title: 'Payment Successful',
              description: 'Your water bill payment of \$45.50 has been processed',
              time: '2 hours ago',
              type: 'success',
              isUnread: true,
            ),
            _buildNotificationItem(
              icon: Icons.water_drop,
              title: 'Usage Alert',
              description: 'You have used 75% of your monthly water allocation',
              time: '4 hours ago',
              type: 'warning',
              isUnread: true,
            ),

            const SizedBox(height: 24),

            // Yesterday Section
            _buildSectionHeader('Yesterday'),
            const SizedBox(height: 16),

            _buildNotificationItem(
              icon: Icons.receipt_long,
              title: 'New Bill Available',
              description: 'Your November water bill is ready for viewing',
              time: '1 day ago',
              type: 'info',
              isUnread: false,
            ),

            const SizedBox(height: 24),

            // This Week Section
            _buildSectionHeader('This Week'),
            const SizedBox(height: 16),

            _buildNotificationItem(
              icon: Icons.update,
              title: 'System Update',
              description: 'New features added to your dashboard',
              time: '2 days ago',
              type: 'info',
              isUnread: false,
            ),
            _buildNotificationItem(
              icon: Icons.security,
              title: 'Security Alert',
              description: 'New login detected from your account',
              time: '3 days ago',
              type: 'warning',
              isUnread: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          'Clear',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    required String type,
    required bool isUnread,
  }) {
    Color backgroundColor;
    Color iconColor;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green.withOpacity(0.1);
        iconColor = Colors.green;
        break;
      case 'warning':
        backgroundColor = Colors.orange.withOpacity(0.1);
        iconColor = Colors.orange;
        break;
      case 'info':
        backgroundColor = Colors.blue.withOpacity(0.1);
        iconColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blueAccent.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? Colors.blueAccent.withOpacity(0.2) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isUnread ? Colors.black87 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
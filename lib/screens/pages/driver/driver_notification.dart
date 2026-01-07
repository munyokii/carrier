import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/driver/shipment_detail.dart';

class DriverNotifications extends StatefulWidget {
  const DriverNotifications({super.key});

  @override
  State<DriverNotifications> createState() => _DriverNotificationsState();
}

class _DriverNotificationsState extends State<DriverNotifications> {
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final querySnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: _currentUid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text("Mark all read"),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: _currentUid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return GestureDetector(
                onTap: () async {
                  // 1. Mark as read immediately for better UX
                  if (!isRead) {
                    _markAsRead(doc.id);
                  }

                  final String? bookingId = data['bookingId'];

                  if (bookingId != null && bookingId.isNotEmpty) {
                    // 2. Show a loading indicator while fetching the booking data
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      // 3. Fetch the full booking document
                      DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(bookingId)
                          .get();

                      // 4. Close the loading indicator
                      if (!mounted) return;
                      Navigator.pop(context);

                      if (bookingDoc.exists) {
                        // 5. Convert to your model and navigate
                        final booking = BookingModel.fromFirestore(
                          bookingDoc.data() as Map<String, dynamic>, 
                          bookingDoc.id
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShipmentDetail(booking: booking),
                          ),
                        );
                      } else {
                        _showErrorSnackBar("This shipment record no longer exists.");
                      }
                    } catch (e) {
                      if (mounted) Navigator.pop(context); // Close loader
                      _showErrorSnackBar("Error fetching shipment details.");
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeadingIcon(data['type'], isRead),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('HH:mm').format(createdAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['body'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeadingIcon(String? type, bool isRead) {
    IconData icon;
    Color color;

    switch (type) {
      case 'assignment':
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case 'payment':
        icon = Icons.account_balance_wallet;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.orange;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: isRead ? Colors.grey[200] : color.withOpacity(0.1),
      child: Icon(icon, color: isRead ? Colors.grey : color, size: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No notifications yet", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
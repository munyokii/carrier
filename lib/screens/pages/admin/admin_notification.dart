import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});

  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  @override
  void initState() {
    super.initState();
    _markAllAsReadByAdmin();
  }

  Future<void> _markAllAsReadByAdmin() async {
    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collectionGroup('status_history')
          .where('readByAdmin', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'readByAdmin': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking admin notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('status_history')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Error: ${snapshot.error}. Check Firestore Index."),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildNotificationTile(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> data) {
    final String status = data['status'] ?? 'update';
    final DateTime time = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    final bool isUnread = data['readByAdmin'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isUnread ? Border.all(color: Colors.blue.withOpacity(0.1)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withOpacity(0.1),
          child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 20),
        ),
        title: Text(
          data['message'] ?? "System Update",
          style: TextStyle(
            fontSize: 14, 
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
            color: isUnread ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (data['bookingId'] != null)
              Text("Shipment ID: ${data['bookingId']}", 
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            Text(
              DateFormat('MMM dd, hh:mm a').format(time),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: isUnread 
            ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))
            : null,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'out_for_delivery': return Colors.blue;
      case 'accepted': return Colors.teal;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.indigo;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.verified;
      case 'out_for_delivery': return Icons.local_shipping;
      case 'accepted': return Icons.assignment_turned_in;
      case 'pending': return Icons.new_releases;
      case 'cancelled': return Icons.cancel;
      default: return Icons.notifications_active;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "No system activity recorded", 
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
          ),
          const Text(
            "Driver and customer events will appear here.", 
            style: TextStyle(color: Colors.grey, fontSize: 12)
          ),
        ],
      ),
    );
  }
}
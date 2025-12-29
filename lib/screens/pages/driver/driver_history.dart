import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:intl/intl.dart';

class DriverHistory extends StatefulWidget {
  const DriverHistory({super.key});

  @override
  State<DriverHistory> createState() => _DriverHistoryState();
}

class _DriverHistoryState extends State<DriverHistory> {
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Function to calculate start of the current week (Monday)
  DateTime _getStartOfWeek() {
    DateTime now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1)).copyWith(hour: 0, minute: 0, second: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startOfWeek = _getStartOfWeek();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Delivery History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('carrierId', isEqualTo: _currentUid)
            .where('status', isEqualTo: 'delivered')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyHistory();
          }

          final allDocs = snapshot.data!.docs;
          
          // Calculate Weekly Earnings (Example: KES 500 per delivery if no price field exists)
          double weeklyTotal = 0;
          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp).toDate();
            if (createdAt.isAfter(startOfWeek)) {
              weeklyTotal += 500.0; // Replace with actual booking.price if available
            }
          }

          return Column(
            children: [
              _buildEarningsSummary(weeklyTotal, theme),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allDocs.length,
                  itemBuilder: (context, index) {
                    final booking = BookingModel.fromFirestore(
                      allDocs[index].data() as Map<String, dynamic>, 
                      allDocs[index].id
                    );
                    return _buildHistoryCard(booking);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEarningsSummary(double total, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("THIS WEEK'S EARNINGS", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "KES ${NumberFormat("#,##0.00").format(total)}",
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text("Payout scheduled for Sunday", style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BookingModel booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.check, color: Colors.green),
        ),
        title: Text(booking.itemDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tracking: ${booking.trackingNumber}"),
            Text(DateFormat('MMM dd, yyyy • hh:mm a').format(booking.createdAt), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "KES ${booking.price.toStringAsFixed(2)}", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)
            ),
            const Text("Completed", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No completed jobs yet", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
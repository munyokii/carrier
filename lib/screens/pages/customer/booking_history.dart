import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/customer/booking_detail.dart';
import 'package:intl/intl.dart';

class BookingHistory extends StatelessWidget {
  const BookingHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Booking History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
            .where('status', whereIn: ['delivered', 'cancelled'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyHistory();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final booking = BookingModel.fromFirestore(
                snapshot.data!.docs[index].data() as Map<String, dynamic>,
                snapshot.data!.docs[index].id,
              );
              return _buildHistoryItem(context, booking, primaryColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, BookingModel booking, Color primary) {
    bool isDelivered = booking.status == 'delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookingDetailsScreen(booking: booking)),
        ),
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: (isDelivered ? Colors.green : Colors.red).withOpacity(0.1),
          child: Icon(
            isDelivered ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isDelivered ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          booking.itemDescription,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Tracking ID: ${booking.trackingNumber}", style: const TextStyle(fontSize: 12)),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(booking.createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "KES ${booking.price.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "No completed deliveries yet",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
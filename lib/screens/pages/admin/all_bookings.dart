import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/admin/assign_driver.dart';

class AllBookings extends StatelessWidget {
  const AllBookings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Active Bookings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending bookings found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final booking = BookingModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(booking.stationName.toUpperCase(), 
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 12)),
                          Text(booking.statusDisplayName, 
                            style: TextStyle(color: booking.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(booking.itemDescription, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(height: 25),
                      _buildInfoRow(Icons.location_on_outlined, "To: ${booking.deliveryAddress}"),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.fitness_center, "Weight: ${booking.weight} kg"),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary, 
                            foregroundColor: Theme.of(context).colorScheme.onPrimary, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => AssignDriver(booking: booking)),
                          ),
                          child: const Text("Assign Driver"),
                        ),
                      )
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 13))),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';

class AssignDriver extends StatefulWidget {
  final BookingModel booking;
  const AssignDriver({super.key, required this.booking});

  @override
  State<AssignDriver> createState() => _AssignDriverState();
}

class _AssignDriverState extends State<AssignDriver> {
  bool _isProcessing = false;

  Future<void> _assignDriverToBooking(String driverId, String driverName) async {
    setState(() => _isProcessing = true);
    try {
      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id);
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(bookingRef, {
        'status': 'accepted',
        'carrierId': driverId,
        'carrierName': driverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final customerNotificationRef = bookingRef.collection('status_history').doc();
      batch.set(customerNotificationRef, {
        'status': 'accepted',
        'message': 'Your shipment has been accepted by driver $driverName',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.booking.userId,
        'read': false,
      });

      final driverNotificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(driverNotificationRef, {
        'receiverId': driverId,
        'title': 'New Shipment Assigned',
        'body': 'You have been assigned to shipment ${widget.booking.trackingNumber}',
        'bookingId': widget.booking.id,
        'type': 'assignment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver Assigned & Customer Notified!"))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Assignment Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Select Online Driver", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('drivers')
                .where('stationId', isEqualTo: widget.booking.stationId)
                .where('status', isEqualTo: 'active')
                .where('isOnline', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error: Check console to create index"));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        "No online drivers at this hub.",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final driverDoc = snapshot.data!.docs[index];
                  final driver = driverDoc.data() as Map<String, dynamic>;
                  final dId = driverDoc.id;
                  final dName = driver['fullName'] ?? "Unknown";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(dName[0], style: TextStyle(color: Theme.of(context).primaryColor)),
                      ),
                      title: Text(dName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${driver['vehicleType']} • ${driver['experienceYears']}y Exp"),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onTap: () => _assignDriverToBooking(dId, dName),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
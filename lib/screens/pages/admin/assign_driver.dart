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
      await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).update({
        'status': 'accepted',
        'carrierId': driverId,
        'carrierName': driverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Driver Assigned! Booking Accepted.")));
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
      appBar: AppBar(title: const Text("Select Driver")),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('drivers')
                .where('status', isEqualTo: 'active')
                .where('stationId', isEqualTo: widget.booking.stationId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No available drivers at this hub."));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final driver = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final dId = snapshot.data!.docs[index].id;
                  final dName = driver['fullName'] ?? "Unknown";

                  return ListTile(
                    leading: CircleAvatar(child: Text(dName[0])),
                    title: Text(dName),
                    subtitle: Text("${driver['vehicleType']} • ${driver['experienceYears']}y Exp"),
                    trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onTap: () => _assignDriverToBooking(dId, dName),
                  );
                },
              );
            },
          ),
    );
  }
}
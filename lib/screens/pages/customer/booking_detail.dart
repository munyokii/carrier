import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsScreen({super.key, required this.booking});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _isCancelling = false;

  // HELPER: Generates a consistent color based on the driver's name
  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> avatarColors = [
      Colors.blue.shade400,
      Colors.indigo.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.cyan.shade400,
      Colors.deepOrange.shade400,
    ];
    return avatarColors[hash.abs() % avatarColors.length];
  }

  // HELPER: To launch the phone dialer
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // NEW: Cancel Functionality
  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this delivery request? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No, Keep it")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .update({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking cancelled successfully"), backgroundColor: Colors.redAccent),
          );
          Navigator.pop(context); // Go back to Dashboard
        }
      } catch (e) {
        debugPrint("Error cancelling: $e");
      } finally {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bool isAssigned = widget.booking.carrierId.isNotEmpty;
    final bool isPending = widget.booking.status == 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Delivery Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Status Update"),
            _buildStatusCard(widget.booking),
            const SizedBox(height: 25),

            _buildSectionHeader("Package Details"),
            _buildInfoTile("Item", widget.booking.itemDescription, Icons.inventory_2_outlined),
            _buildInfoTile("Weight", "${widget.booking.weight} kg", Icons.fitness_center),
            _buildInfoTile("Destination", widget.booking.deliveryAddress, Icons.location_on_outlined),
            _buildInfoTile("Booked On", DateFormat('MMMM dd, yyyy • hh:mm a').format(widget.booking.createdAt), Icons.calendar_today_outlined),
            
            const SizedBox(height: 25),

            _buildSectionHeader("Assigned Carrier"),
            if (!isAssigned)
              _buildEmptyDriverCard()
            else
              _buildDriverProfileStream(widget.booking.carrierId, primaryColor),

            // NEW: Conditional Cancel Button
            if (isPending) ...[
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelBooking,
                  icon: _isCancelling 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.close),
                  label: const Text("CANCEL THIS BOOKING", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("Only pending requests can be cancelled.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title.toUpperCase(), 
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
    );
  }

  Widget _buildStatusCard(BookingModel booking) {
    Color sColor = booking.status == 'accepted' ? Colors.green : booking.statusColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: sColor.withOpacity(0.1),
            child: Icon(booking.statusIcon, color: sColor),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.statusDisplayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sColor)),
              Text("ID: ${booking.trackingNumber}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDriverProfileStream(String driverId, Color primary) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        if (!snapshot.data!.exists) return const Text("Driver details unavailable.");

        final driver = snapshot.data!.data() as Map<String, dynamic>;
        final String name = driver['fullName'] ?? 'Unknown Driver';
        final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final Color avatarBgColor = _getAvatarColor(name);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: avatarBgColor,
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("${driver['vehicleType']} • ${driver['experienceYears']}y Experience", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _makePhoneCall(driver['phone'] ?? ''),
                    icon: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.phone, color: Colors.white, size: 18)),
                  )
                ],
              ),
              const Divider(height: 30),
              _buildDriverSmallDetail("Phone", driver['phone'] ?? 'N/A'),
              _buildDriverSmallDetail("License", driver['licenseNumber'] ?? 'N/A'),
              _buildDriverSmallDetail("Rating", "⭐️ 4.9 (124 deliveries)"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverSmallDetail(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyDriverCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Column(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.orange, size: 30),
          SizedBox(height: 10),
          Text("Waiting for admin assignment...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
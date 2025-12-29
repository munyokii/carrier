import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carrier/screens/login_screen.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/driver/shipment_detail.dart';
import 'package:carrier/screens/pages/driver/driver_history.dart';
import 'package:carrier/screens/pages/driver/driver_wallet.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isOnline = false;
  String _driverName = "Driver";
  String _initial = "D";

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }


  void _loadDriverData() async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(_currentUid).get();
    if (doc.exists && mounted) {
      final data = doc.data();
      setState(() {
        _isOnline = data?['isOnline'] ?? false;
        _driverName = data?['fullName'] ?? "Driver";
        _initial = _driverName.isNotEmpty ? _driverName[0].toUpperCase() : "D";
      });
    }
  }

  void _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);
    await FirebaseFirestore.instance.collection('drivers').doc(_currentUid).update({
      'isOnline': value,
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Color _getAvatarColor(String name) {
    final List<Color> colors = [
      Colors.blue, Colors.orange, Colors.purple, 
      Colors.teal, Colors.indigo, Colors.deepOrange
    ];
    return colors[name.length % colors.length];
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return; 

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _getAvatarColor(_driverName),
              child: Text(
                _initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _driverName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDriverData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(primaryColor),
              const SizedBox(height: 24),

              const Text("Today's Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildLiveStats(primaryColor),
              
              const SizedBox(height: 24),
              const Text("Active Shipment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildActiveShipmentStream(primaryColor),

              const SizedBox(height: 24),
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildQuickActions(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStats(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('carrierId', isEqualTo: _currentUid)
          .where('status', isEqualTo: 'delivered')
          .snapshots(),
      builder: (context, snapshot) {
        int jobsDone = snapshot.hasData ? snapshot.data!.docs.length : 0;
        double totalEarnings = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalEarnings += (data['price'] ?? 0).toDouble(); 
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatItem(
                "Earnings", 
                "KES ${totalEarnings.toStringAsFixed(2)}", 
                Icons.payments_outlined, 
                Colors.green
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatItem(
                "Jobs Done", 
                "$jobsDone", 
                Icons.local_shipping_outlined, 
                primaryColor
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveShipmentStream(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('carrierId', isEqualTo: _currentUid)
          .where('status', whereIn: ['accepted', 'out_for_delivery'])
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final bookingData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final booking = BookingModel.fromFirestore(bookingData, snapshot.data!.docs.first.id);

        return _buildShipmentCard(booking, primaryColor);
      },
    );
  }

  Widget _buildShipmentCard(BookingModel booking, Color primaryColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(booking.statusIcon, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(booking.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          _buildStatusBadge(booking),
                        ],
                      ),
                      Text("${booking.itemDescription} • ${booking.weight}kg", 
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _locationPoint("PICKUP", booking.stationName),
                Icon(Icons.multiple_stop, size: 20, color: primaryColor.withOpacity(0.3)),
                _locationPoint("DESTINATION", booking.deliveryAddress.split(',').first),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ShipmentDetail(booking: booking)),
                );
              },
              child: const Text("VIEW SHIPMENT DETAILS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
          ],
        ),
      ),
    );
  }


  Widget _buildStatusCard(Color primaryColor) {
    return Card(
      color: _isOnline ? primaryColor : Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Current Status", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_isOnline ? "Online & Available" : "Offline",
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            Switch(
              value: _isOnline,
              activeColor: Colors.white,
              onChanged: _toggleOnlineStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("All Caught Up!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("No active shipments assigned to you.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BookingModel booking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: booking.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        booking.statusDisplayName,
        style: TextStyle(color: booking.statusColor, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _locationPoint(String label, String city) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    final actions = [
      {'icon': Icons.history, 'label': 'History'},
      {'icon': Icons.account_balance_wallet_outlined, 'label': 'Wallet'},
      {'icon': Icons.headset_mic_outlined, 'label': 'Support'},
      {'icon': Icons.settings_outlined, 'label': 'Settings'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((action) {
        return GestureDetector(
          onTap: () {
            if (action['label'] == 'History') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverHistory()));
            } else if (action['label'] == 'Wallet') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverWallet()));
            }
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Icon(action['icon'] as IconData, color: primaryColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(action['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
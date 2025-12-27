import 'package:carrier/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/customer/find_carrier_screen.dart';
// import 'package:carrier/screens/pages/customer/track_package_screen.dart';
import 'package:carrier/models/booking_model.dart';
// import 'package:carrier/screens/pages/customer/package_detail_screen.dart';
import 'package:intl/intl.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _userData = doc.data());
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final userName = _userData?['fullName'] ?? _user?.displayName ?? 'Valued Customer';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userName, primaryColor),
                const SizedBox(height: 20),
                _buildSearchBar(primaryColor),
                const SizedBox(height: 25),
                _buildStatsOverview(),
                const SizedBox(height: 25),
                _buildPromoBanner(primaryColor),
                const SizedBox(height: 30),
                _buildQuickActions(primaryColor),
                const SizedBox(height: 30),
                _buildActiveDeliveries(theme),
                const SizedBox(height: 30),
                _buildRecentActivity(theme),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, Color primary) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: primary.withOpacity(0.1),
          child: Text(name[0].toUpperCase(), style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getGreeting(), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        )
      ],
    );
  }

  Widget _buildSearchBar(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Enter Tracking ID...",
          prefixIcon: Icon(Icons.search, color: primary),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem("Ongoing", "12", Colors.orange),
        _buildStatItem("Delivered", "48", Colors.green),
        _buildStatItem("Canceled", "2", Colors.red),
      ],
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("20% OFF", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text("On your next heavy truck delivery!", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Claim"),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildCircularAction(Icons.local_shipping, "Send", primaryColor, () => _navTo(const FindCarrierScreen())),
        _buildCircularAction(Icons.track_changes, "Track", Colors.blue, () => _navTo(const Placeholder())),
        _buildCircularAction(Icons.inventory, "History", Colors.purple, () => _navTo(const Placeholder())),
        _buildCircularAction(Icons.help_center, "Support", Colors.teal, () {}),
      ],
    );
  }

  Widget _buildCircularAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActiveDeliveries(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Active Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: _user?.uid)
              .where('status', whereIn: ['pending', 'accepted', 'in_transit'])
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState("No active deliveries", Icons.local_shipping_outlined);
            }
            return SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final booking = BookingModel.fromFirestore(
                    snapshot.data!.docs[index].data() as Map<String, dynamic>,
                    snapshot.data!.docs[index].id,
                  );
                  return _buildDeliveryCard(booking, theme.colorScheme.primary);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(BookingModel booking, Color primary) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(booking.statusDisplayName.toUpperCase(), style: TextStyle(color: booking.statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              Icon(booking.statusIcon, color: booking.statusColor, size: 18),
            ],
          ),
          const Divider(height: 20),
          Text(booking.carrierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(booking.vehicleType, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          LinearProgressIndicator(
            value: (booking.statusProgress + 1) / 4,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(booking.statusColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(child: Text(booking.deliveryAddress, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').where('userId', isEqualTo: _user?.uid).limit(5).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState("No recent activity", Icons.history);
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final booking = BookingModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: booking.statusColor.withOpacity(0.1), child: Icon(booking.statusIcon, color: booking.statusColor, size: 20)),
                  title: Text(booking.carrierName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${booking.statusDisplayName} • ${DateFormat('MMM dd').format(booking.createdAt)}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _navTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}
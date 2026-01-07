import 'package:carrier/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/customer/find_carrier_screen.dart';
import 'package:carrier/screens/pages/customer/booking_detail.dart';
import 'package:carrier/screens/pages/customer/track_package.dart';
import 'package:carrier/screens/pages/customer/booking_history.dart';
import 'package:carrier/screens/pages/customer/notification_screen.dart';
import 'package:carrier/models/booking_model.dart';
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

  int _ongoingCount = 0;
  int _deliveredCount = 0;
  int _canceledCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (_user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
      
      final ongoingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: _user.uid)
          .where('status', whereIn: ['pending', 'accepted', 'in_transit', 'out_for_delivery'])
          .count()
          .get();

      final deliveredQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: _user.uid)
          .where('status', isEqualTo: 'delivered')
          .count()
          .get();

      final canceledQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: _user.uid)
          .where('status', isEqualTo: 'cancelled')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _userData = userDoc.data();
          _ongoingCount = ongoingQuery.count ?? 0;
          _deliveredCount = deliveredQuery.count ?? 0;
          _canceledCount = canceledQuery.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFFF8F9FD),
              child: _buildHeader(userName, primaryColor),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5), 
                      _buildStatsOverview(),
                      const SizedBox(height: 25),
                      _buildPromoBanner(primaryColor),
                      const SizedBox(height: 30),
                      _buildQuickActions(primaryColor),
                      const SizedBox(height: 30),
                      _buildActiveDeliveries(theme),
                      const SizedBox(height: 30),
                      _buildRecentHistory(theme),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 20)),
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
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('status_history')
              .where('userId', isEqualTo: _user?.uid)
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

            return IconButton(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const NotificationsScreen())
                );
              },
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 28),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        )
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem("Ongoing", _ongoingCount.toString(), Colors.orange),
        _buildStatItem("Delivered", _deliveredCount.toString(), Colors.green),
        _buildStatItem("Canceled", _canceledCount.toString(), Colors.red),
      ],
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
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
        _buildCircularAction(Icons.track_changes, "Track", Colors.blue, () => _navTo(const TrackPackageScreen())),
        _buildCircularAction(Icons.inventory, "History", Colors.purple, () => _navTo(const BookingHistory())),
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
              .where('status', whereIn: ['pending', 'accepted', 'in_transit', 'out_for_delivery'])
              .orderBy('createdAt', descending: true) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading deliveries"));
            }
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

  Widget _buildHistoryItem(BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: ListTile(
        onTap: () => _navTo(BookingDetailsScreen(booking: booking)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: booking.statusColor.withOpacity(0.1),
          child: Icon(booking.statusIcon, color: booking.statusColor, size: 20),
        ),
        title: Text(
          booking.itemDescription,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${booking.statusDisplayName} • ${DateFormat('MMM dd, yyyy').format(booking.createdAt)}",
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildRecentHistory(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => _navTo(const BookingHistory()),
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: _user?.uid)
              .where('status', whereIn: ['delivered', 'cancelled'])
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LinearProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState("No history found", Icons.history);
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final booking = BookingModel.fromFirestore(
                  snapshot.data!.docs[index].data() as Map<String, dynamic>,
                  snapshot.data!.docs[index].id,
                );
                return _buildHistoryItem(booking);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(BookingModel booking, Color primary) {
    Color statusColor = booking.status == 'accepted' ? Colors.green : booking.statusColor;

    return GestureDetector(
      onTap: () => _navTo(BookingDetailsScreen(booking: booking)),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          border: Border.all(color: Colors.grey[100]!)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(booking.statusDisplayName.toUpperCase(), 
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                Icon(booking.statusIcon, color: statusColor, size: 18),
              ],
            ),
            const Divider(height: 20),
            Text(booking.itemDescription, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(booking.carrierName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Spacer(),
            LinearProgressIndicator(
              value: (booking.statusProgress + 1) / 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
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
      ),
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
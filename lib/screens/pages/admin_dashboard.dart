import 'package:flutter/material.dart';
import 'package:carrier/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import management screens (to be created)
import 'package:carrier/screens/pages/admin/add_station.dart';
// import 'package:carrier/screens/admin/add_driver_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final User? _user = FirebaseAuth.instance.currentUser;
  
  // Analytics State
  int totalDrivers = 0;
  int totalStations = 0;
  int activeShipments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSystemStats();
  }

  Future<void> _fetchSystemStats() async {
    try {
      // Fetch counts from Firestore collections
      final drivers = await FirebaseFirestore.instance.collection('drivers').count().get();
      final stations = await FirebaseFirestore.instance.collection('stations').count().get();
      final shipments = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isNotEqualTo: 'delivered')
          .count()
          .get();

      if (mounted) {
        setState(() {
          totalDrivers = drivers.count ?? 0;
          totalStations = stations.count ?? 0;
          activeShipments = shipments.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional light grey
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _fetchSystemStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 25),
              
              // 1. Stats Overview
              const Text("System Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildStatsGrid(primaryColor),
              
              const SizedBox(height: 30),
              
              // 2. Administrative Actions
              const Text("Management Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildAdminActions(context, primaryColor),
              
              const SizedBox(height: 30),
              
              // 3. Recent Activity / Logs
              const Text("System Logs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildSystemLogs(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AppBar(
      title: const Text(
        "Swiftline Admin", 
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        // Notification Icon with Badge
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined, color: Colors.grey[800]),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {
            // TODO: Navigate to Admin Notifications
          },
        ),
        
        // Search Icon
        IconButton(
          onPressed: () {}, 
          icon: Icon(Icons.search, color: Colors.grey[800]),
        ),
        
        // Logout Icon
        IconButton(
          onPressed: () => _handleLogout(context), 
          icon: const Icon(Icons.logout, color: Colors.red),
        ),
      ],
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hello, ${_user?.email?.split('@')[0]} 👋",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text("Here is what's happening with the fleet today."),
      ],
    );
  }

  Widget _buildStatsGrid(Color primaryColor) {
    return Row(
      children: [
        _buildStatCard("Drivers", totalDrivers.toString(), Icons.person, Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard("Stations", totalStations.toString(), Icons.hub, Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard("Active", activeShipments.toString(), Icons.local_shipping, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, Color primaryColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      children: [
        _buildActionTile(
          context, 
          "Add Station", 
          Icons.add_business_rounded, 
          primaryColor,
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => AddStation())),
        ),
        _buildActionTile(
          context, 
          "Add Driver", 
          Icons.person_add_alt_1_rounded, 
          Colors.indigo,
          () => {} // Navigator.push(context, MaterialPageRoute(builder: (c) => AddDriverScreen())),
        ),
        _buildActionTile(context, "All Users", Icons.group_outlined, Colors.teal, () {}),
        _buildActionTile(context, "Reports", Icons.analytics_outlined, Colors.purple, () {}),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemLogs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: List.generate(3, (index) => _buildLogItem(index)),
      ),
    );
  }

  Widget _buildLogItem(int index) {
    List<String> logs = [
      "New Driver 'John Doe' registered.",
      "Station 'Nairobi West' status updated to Active.",
      "System backup completed successfully."
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(logs[index], style: const TextStyle(fontSize: 13))),
          Text("2m ago", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
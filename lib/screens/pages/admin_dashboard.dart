import 'package:flutter/material.dart';
import 'package:carrier/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// Import your station screen
import 'package:carrier/screens/pages/admin/add_station.dart';
import 'package:carrier/screens/pages/admin/add_driver.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final User? _user = FirebaseAuth.instance.currentUser;
  
  int totalDrivers = 0;
  int totalStations = 0;
  int activeShipments = 0;
  // bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSystemStats();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchSystemStats() async {
    try {
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
          // _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _getRecentStations() {
    return FirebaseFirestore.instance
        .collection('stations')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context, primaryColor),
      body: RefreshIndicator(
        onRefresh: _fetchSystemStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 25),
              
              // 1. Stats Overview
              _buildSectionTitle("System Overview"),
              const SizedBox(height: 15),
              _buildStatsGrid(primaryColor),
              
              const SizedBox(height: 30),
              
              // 2. Administrative Actions
              _buildSectionTitle("Management Actions"),
              const SizedBox(height: 15),
              _buildAdminActions(context, primaryColor),
              
              const SizedBox(height: 30),

              // 3. Recent Stations Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Recent Stations"),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigator.push(context, MaterialPageRoute(builder: (c) => const AllStationsScreen()));
                    }, 
                    child: const Text("View All")
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildStationHorizontalList(),
              
              const SizedBox(height: 30),
              
              // 4. System Logs
              _buildSectionTitle("System Logs"),
              const SizedBox(height: 15),
              _buildSystemLogs(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Color primaryColor) {
    return AppBar(
      title: const Text("Swiftline Admin", style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined, color: Colors.grey[800]),
              Positioned(
                right: 0, top: 0,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
              ),
            ],
          ),
          onPressed: () {},
        ),
        IconButton(onPressed: () {}, icon: Icon(Icons.search, color: Colors.grey[800])),
        IconButton(
          onPressed: () => _handleLogout(context), 
          icon: const Icon(Icons.logout, color: Colors.red)
        ),
      ],
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
        const Text("Monitoring fleet operations and station health."),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
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
      childAspectRatio: 1.5,
      children: [
        _buildActionTile(context, "Add Station", Icons.add_business_rounded, primaryColor, 
            () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddStation()))),
        _buildActionTile(context, "Add Driver", Icons.person_add_alt_1_rounded, Colors.indigo,
            () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddDriver()))),
        _buildActionTile(context, "All Users", Icons.group_outlined, Colors.teal, () {}),
        _buildActionTile(context, "Reports", Icons.analytics_outlined, Colors.purple, () {}),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Keep background white for a clean look
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5), // The colored border
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon now uses the specific color
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            // Text now uses the specific color
            Text(
              title, 
              style: TextStyle(
                color: color, 
                fontWeight: FontWeight.bold, 
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationHorizontalList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getRecentStations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No stations found.");
        }

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final station = snapshot.data![index];
              return _buildStationCard(station);
            },
          ),
        );
      },
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final status = station['status'] ?? 'active';
    final bool isActive = status.toString().toLowerCase() == 'active';

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 15, bottom: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFF6E00).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.hub_outlined, size: 20, color: Color(0xFFFF6E00)),
              ),
              _buildStatusBadge(status, isActive),
            ],
          ),
          const Spacer(),
          Text(
            station['stationName'] ?? 'Unknown Station',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            "CODE: ${station['stationCode'] ?? 'N/A'}",
            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildSystemLogs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: List.generate(3, (index) {
          final logs = ["New driver registered", "Nairobi hub active", "System backup OK"];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(child: Text(logs[index], style: const TextStyle(fontSize: 13))),
                Text("2m ago", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginScreen()), (r) => false);
    }
  }
}
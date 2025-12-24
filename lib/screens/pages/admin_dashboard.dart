import 'package:flutter/material.dart';
import 'package:carrier/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your screens
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _getRecentData(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
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
              
              // 2. Management Actions
              _buildSectionTitle("Management Actions"),
              const SizedBox(height: 15),
              _buildAdminActions(context, primaryColor),
              
              const SizedBox(height: 30),

              // 3. Recent Stations Section
              _buildListHeader("Recent Stations", () {
                // TODO: Navigator.push(context, MaterialPageRoute(builder: (c) => const AllStationsScreen()));
              }),
              const SizedBox(height: 10),
              _buildStationHorizontalList(),
              
              const SizedBox(height: 30),

              // 4. Recent Drivers Section (New)
              _buildListHeader("Recent Drivers", () {
                // TODO: Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDriversScreen()));
              }),
              const SizedBox(height: 10),
              _buildDriverHorizontalList(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- SHARED UI COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    );
  }

  Widget _buildListHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        TextButton(onPressed: onViewAll, child: const Text("View All")),
      ],
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
        const Text("Monitoring fleet operations and system health."),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // --- RECENT STATIONS LIST ---
  Widget _buildStationHorizontalList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getRecentData('stations'),
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
            itemBuilder: (context, index) => _buildDataCard(snapshot.data![index], isStation: true),
          ),
        );
      },
    );
  }

  // --- RECENT DRIVERS LIST (NEW) ---
  Widget _buildDriverHorizontalList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getRecentData('drivers'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No drivers registered.");
        }

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) => _buildDataCard(snapshot.data![index], isStation: false),
          ),
        );
      },
    );
  }

  Widget _buildDataCard(Map<String, dynamic> data, {required bool isStation}) {
    final status = data['status'] ?? 'active';
    final bool isActive = status.toString().toLowerCase() == 'active';
    final String title = isStation ? (data['stationName'] ?? 'Unnamed') : (data['fullName'] ?? 'Unnamed');
    final String subtitle = isStation ? "CODE: ${data['stationCode']}" : "${data['vehicleType'] ?? 'No Vehicle'}";

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
                decoration: BoxDecoration(
                  color: (isStation ? Colors.orange : Colors.indigo).withOpacity(0.1), 
                  shape: BoxShape.circle
                ),
                child: Icon(isStation ? Icons.hub_outlined : Icons.person_outline, size: 20, color: isStation ? Colors.orange : Colors.indigo),
              ),
              _buildStatusBadge(status, isActive),
            ],
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isActive) {
    Color badgeColor = isActive ? Colors.green : Colors.orange;
    if (status.contains('pending')) badgeColor = Colors.orange;
    if (status.contains('inactive')) badgeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
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

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginScreen()), (r) => false);
    }
  }
}
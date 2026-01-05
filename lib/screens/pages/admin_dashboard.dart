import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:carrier/screens/login_screen.dart';
import 'package:carrier/screens/pages/admin/add_station.dart';
import 'package:carrier/screens/pages/admin/add_driver.dart';
import 'package:carrier/screens/pages/admin/all_drivers.dart';
import 'package:carrier/screens/pages/admin/driver_detail.dart';
import 'package:carrier/screens/pages/admin/all_stations.dart';
import 'package:carrier/screens/pages/admin/station_detail.dart';
import 'package:carrier/screens/pages/admin/all_bookings.dart';
import 'package:carrier/screens/pages/admin/admin_reports.dart';
import 'package:carrier/screens/pages/admin/admin_notification.dart';

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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to sign out from the Admin panel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                  (route) => false,
                );
              }
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(primaryColor),
      body: RefreshIndicator(
        onRefresh: _fetchSystemStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 25),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle("Management Actions"),
                    const SizedBox(height: 15),
                    _buildAdminActions(context, primaryColor),
                  ],
                ),
              ),

              _buildListHeader("Recent Bookings", () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AllBookings()));
              }),
              _buildRecentBookingsRow(),

              _buildListHeader("Stations", () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AllStations()));
              }),
              _buildStationCardsRow(),
              
              const SizedBox(height: 25),

              _buildListHeader("Drivers", () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDrivers()));
              }),
              _buildRecentDriversList(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar(Color primaryColor) => AppBar(
    title: const Text("Swiftline Admin", style: TextStyle(fontWeight: FontWeight.bold)),
    backgroundColor: Colors.white,
    elevation: 0.5,
    actions: [
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('status_history')
            .where('readByAdmin', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

          return IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminNotifications()),
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
                      decoration: const BoxDecoration(
                        color: Colors.red,
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
        onPressed: _showLogoutDialog, 
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _buildWelcomeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Hello, ${_user?.email?.split('@')[0]} 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const Text("Fleet operations directory", style: TextStyle(color: Colors.grey)),
    ],
  );

  Widget _buildStatsGrid() => Row(
    children: [
      _buildStatCard("Drivers", totalDrivers.toString(), Icons.person, Colors.blue),
      const SizedBox(width: 12),
      _buildStatCard("Stations", totalStations.toString(), Icons.hub, Colors.orange),
      const SizedBox(width: 12),
      _buildStatCard("Active", activeShipments.toString(), Icons.local_shipping, Colors.green),
    ],
  );

  Widget _buildStatCard(String title, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey))
        ]
      ),
    ),
  );

  Widget _buildAdminActions(BuildContext context, Color color) => GridView.count(
    shrinkWrap: true, 
    physics: const NeverScrollableScrollPhysics(), 
    crossAxisCount: 2, 
    crossAxisSpacing: 15, 
    mainAxisSpacing: 15, 
    childAspectRatio: 1.6,
    children: [
      _buildActionTile(context, "Add Station", Icons.add_business, color, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddStation()))),
      _buildActionTile(context, "Add Driver", Icons.person_add, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddDriver()))),
      _buildActionTile(context, "Bookings", Icons.inventory_2, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AllBookings()))),
      _buildActionTile(context, "Reports", Icons.analytics, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReports()))),
    ],
  );

  Widget _buildActionTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap, 
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: color), 
          const SizedBox(height: 5), 
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))
        ]
      )
    ),
  );

  Widget _buildRecentBookingsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No recent bookings found.");

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildBookingCard(data, doc.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> data, String id) {
    Color statusColor;
    String status = data['status'] ?? 'pending';
    switch (status) {
      case 'delivered': statusColor = Colors.blue; break;
      case 'cancelled': statusColor = Colors.red; break;
      case 'out_for_delivery': statusColor = Colors.purple; break;
      default: statusColor = Colors.green;
    }

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 15, bottom: 10, top: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
            ],
          ),
          const Spacer(),
          Text(
            data['itemDescription'] ?? 'No Description',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            "Tracking: ${data['trackingNumber'] ?? 'N/A'}",
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const Divider(height: 15),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  data['deliveryAddress'] ?? 'No Address',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationCardsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stations')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No stations found.");

        return SizedBox(
          height: 190, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; 
              return _buildStationMapCard(data);
            },
          ),
        );
      },
    );
  }

  Widget _buildStationMapCard(Map<String, dynamic> data) {
    final String stationId = data['id'] ?? '';
    final geoPoint = data['coordinates'] as GeoPoint?;
    final LatLng location = geoPoint != null 
        ? LatLng(geoPoint.latitude, geoPoint.longitude) 
        : LatLng(0, 0);

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 15, bottom: 8, top: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (stationId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StationDetail(stationId: stationId, stationData: data),
                ),
              );
            }
          },
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 100,
                  child: AbsorbPointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: location,
                        initialZoom: 13.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.swiftline.carrier',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: location,
                              width: 30, height: 30,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 25),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(data['stationName'] ?? 'Unnamed Hub', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        _buildSmallStatusBadge(data['status'] ?? 'active'),
                      ],
                    ),
                    Text("Code: ${data['stationCode'] ?? 'N/A'}", 
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDriversList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No drivers found.");

        return Container(
          color: Colors.white,
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String fullName = data['fullName'] ?? 'Unnamed';
              final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: _getAvatarColor(fullName),
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${data['vehicleType']} • ${data['licenseNumber']}"),
                    trailing: _buildSmallStatusBadge(data['status'] ?? 'pending'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => DriverDetail(driverId: doc.id, driverData: data)),
                    ),
                  ),
                  const Divider(height: 1, indent: 80, endIndent: 20, color: Color(0xFFEEEEEE)),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> avatarColors = [
      Colors.blue.shade400, Colors.indigo.shade400, Colors.teal.shade400,
      Colors.pink.shade400, Colors.orange.shade400, Colors.purple.shade400,
      Colors.cyan.shade400,
    ];
    return avatarColors[hash.abs() % avatarColors.length];
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildListHeader(String title, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        TextButton(onPressed: onTap, child: const Text("View All")),
      ],
    ),
  );

  Widget _buildSmallStatusBadge(String status) {
    Color color = status == 'active' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.split('_')[0].toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String msg) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(msg, style: const TextStyle(color: Colors.grey))));
}
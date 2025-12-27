import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class StationDetail extends StatelessWidget {
  final String stationId;
  final Map<String, dynamic> stationData;

  const StationDetail({super.key, required this.stationId, required this.stationData});

  @override
  Widget build(BuildContext context) {
    final geoPoint = stationData['coordinates'] as GeoPoint?;
    final LatLng location = LatLng(geoPoint?.latitude ?? 0, geoPoint?.longitude ?? 0);
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(stationData['stationName'] ?? "Station Details"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. INTERACTIVE MAP HEADER
            SizedBox(
              height: 250,
              child: FlutterMap(
                options: MapOptions(initialCenter: location, initialZoom: 14.0),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.carrier',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. BASIC INFO SECTION
                  _buildSectionTitle("Basic Information"),
                  _buildInfoTile("Station Code", stationData['stationCode'], Icons.qr_code),
                  _buildInfoTile("Station Type", stationData['stationType'], Icons.category_outlined),
                  _buildInfoTile("Status", stationData['status'], Icons.info_outline, isStatus: true),
                  
                  const Divider(height: 40),

                  // 3. LOCATION DETAILS
                  _buildSectionTitle("Location Details"),
                  _buildInfoTile("Physical Address", stationData['address'], Icons.map_outlined),
                  _buildInfoTile("GPS Coordinates", "${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}", Icons.explore_outlined),

                  const Divider(height: 40),

                  // 4. MANAGEMENT DETAILS
                  _buildSectionTitle("Management"),
                  _buildInfoTile("Station Manager", stationData['managerName'], Icons.person_outline),
                  _buildInfoTile("Contact Phone", stationData['contactPhone'], Icons.phone_outlined),

                  const Divider(height: 40),

                  // 5. DRIVERS RELATION LIST
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Assigned Drivers"),
                      const Icon(Icons.local_shipping_outlined, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('drivers')
                        .where('stationId', isEqualTo: stationId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: LinearProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text("No drivers assigned to this hub.", style: TextStyle(color: Colors.grey))),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          var driver = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            tileColor: Colors.grey[50],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Text(driver['fullName'][0].toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(driver['fullName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(driver['vehicleType']),
                            trailing: _buildStatusBadge(driver['status']),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoTile(String label, String? value, IconData icon, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                isStatus 
                  ? _buildStatusBadge(value ?? 'active') 
                  : Text(value ?? 'Not Provided', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'active' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
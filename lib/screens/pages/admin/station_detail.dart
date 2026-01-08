import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class StationDetail extends StatelessWidget {
  final String stationId;
  final Map<String, dynamic> stationData;

  const StationDetail({super.key, required this.stationId, required this.stationData});

  void _showAssignDriverSheet(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Assign Driver to Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('drivers')
                    .where('status', isEqualTo: 'active')
                    .where('stationId', whereIn: ['', null])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final availableDrivers = snapshot.data!.docs;

                  if (availableDrivers.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          "No unassigned drivers available.\nAll active drivers are currently at a station.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: availableDrivers.length,
                    itemBuilder: (context, index) {
                      final doc = availableDrivers[index];
                      final driver = doc.data() as Map<String, dynamic>;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: Text(driver['fullName'][0].toUpperCase(), style: TextStyle(color: primaryColor)),
                        ),
                        title: Text(driver['fullName']),
                        subtitle: Text("${driver['vehicleType']} • ${driver['experienceYears']}y Exp"),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('drivers')
                                .doc(doc.id)
                                .update({'stationId': stationId});
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("${driver['fullName']} assigned to ${stationData['stationName']}"))
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        actions: [
          TextButton.icon(
            onPressed: () => _showAssignDriverSheet(context),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text("Assign"),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        width: 40, height: 40,
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
                  _buildSectionTitle("Basic Information"),
                  _buildInfoTile("Station Code", stationData['stationCode'], Icons.qr_code),
                  _buildInfoTile("Station Type", stationData['stationType'], Icons.category_outlined),
                  _buildInfoTile("Status", stationData['status'], Icons.info_outline, isStatus: true),
                  
                  const Divider(height: 40),

                  _buildSectionTitle("Location Details"),
                  _buildInfoTile("Physical Address", stationData['address'], Icons.map_outlined),
                  _buildInfoTile("GPS Coordinates", "${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}", Icons.explore_outlined),

                  const Divider(height: 40),

                  _buildSectionTitle("Management"),
                  _buildInfoTile("Station Manager", stationData['managerName'], Icons.person_outline),
                  _buildInfoTile("Contact Phone", stationData['contactPhone'], Icons.phone_outlined),

                  const Divider(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Current Fleet"),
                      IconButton(
                        onPressed: () => _showAssignDriverSheet(context),
                        icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                      )
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
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            children: [
                              const Text("No drivers assigned.", style: TextStyle(color: Colors.grey)),
                              TextButton(onPressed: () => _showAssignDriverSheet(context), child: const Text("Assign Now"))
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var driver = doc.data() as Map<String, dynamic>;
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
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'remove', child: Text("Remove from Station", style: TextStyle(color: Colors.red))),
                              ],
                              onSelected: (val) async {
                                if (val == 'remove') {
                                  await FirebaseFirestore.instance.collection('drivers').doc(doc.id).update({'stationId': ''});
                                }
                              },
                            ),
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
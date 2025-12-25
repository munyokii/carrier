import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart'; // Add to pubspec to enable calling

class StationDetail extends StatelessWidget {
  final String stationId;
  final Map<String, dynamic> stationData;

  const StationDetail({super.key, required this.stationId, required this.stationData});

  @override
  Widget build(BuildContext context) {
    final geoPoint = stationData['coordinates'] as GeoPoint?;
    final LatLng location = LatLng(geoPoint?.latitude ?? 0, geoPoint?.longitude ?? 0);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(stationData['stationName'] ?? "Station Details", style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INTERACTIVE MAP HEADER
            SizedBox(
              height: 250,
              child: FlutterMap(
                options: MapOptions(initialCenter: location, initialZoom: 15.0),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.swiftline.carrier',
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
                  _buildHeaderSection(stationData),
                  const Divider(height: 40),
                  
                  _buildSectionTitle("Location Details"),
                  _buildInfoTile("Physical Address", stationData['address'], Icons.map_outlined),
                  _buildInfoTile("Coordinates", "${location.latitude}, ${location.longitude}", Icons.explore_outlined),
                  
                  const SizedBox(height: 20),
                  
                  _buildSectionTitle("Management"),
                  _buildInfoTile("Manager Name", stationData['managerName'], Icons.person_outline),
                  _buildInfoTile("Contact Phone", stationData['contactPhone'], Icons.phone_outlined),
                  
                  const SizedBox(height: 40),
                  
                  // NAVIGATION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _openInNativeMaps(location),
                      icon: const Icon(Icons.directions),
                      label: const Text("Navigate to Station", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['stationType'].toString().toUpperCase(), 
                 style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
            Text(data['stationName'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Station Code: ${data['stationCode']}", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        _buildStatusBadge(data['status'] ?? 'active'),
      ],
    );
  }

  Widget _buildInfoTile(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _openInNativeMaps(LatLng loc) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
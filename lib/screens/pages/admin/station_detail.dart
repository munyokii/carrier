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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(stationData['stationName'])),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(initialCenter: location, initialZoom: 13.0),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  MarkerLayer(markers: [Marker(point: location, child: const Icon(Icons.location_on, color: Colors.red))]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("STATION DRIVERS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // RELATION QUERY
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('drivers')
                        .where('stationId', isEqualTo: stationId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text("No drivers assigned to this hub.");
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          var driver = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(driver['fullName']),
                            subtitle: Text(driver['vehicleType']),
                            trailing: Text(driver['status'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
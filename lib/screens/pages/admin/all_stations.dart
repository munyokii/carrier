import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/admin/station_detail.dart';

class AllStations extends StatefulWidget {
  const AllStations({super.key});

  @override
  State<AllStations> createState() => _AllStationsState();
}

class _AllStationsState extends State<AllStations> {
  String _searchQuery = "";

  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> avatarColors = [
      Colors.orange.shade400, Colors.deepOrange.shade400, Colors.amber.shade600,
      Colors.red.shade400, Colors.brown.shade400, Colors.blueGrey.shade400,
    ];
    return avatarColors[hash.abs() % avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Carrier Network", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search stations...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F6F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('stations').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs.where((d) {
                  return d['stationName'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (c, i) => const Divider(height: 1, indent: 80, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String name = data['stationName'] ?? 'Unnamed';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: _getAvatarColor(name),
                        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${data['stationType']} • ${data['stationCode']}"),
                      trailing: _buildStatusDot(data['status'] ?? 'active'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => StationDetail(stationId: docs[index].id, stationData: data))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color color = status == 'active' ? Colors.green : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
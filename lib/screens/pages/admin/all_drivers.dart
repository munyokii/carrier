import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/admin/driver_detail.dart';

class AllDrivers extends StatefulWidget {
  const AllDrivers({super.key});

  @override
  State<AllDrivers> createState() => _AllDriversState();
}

class _AllDriversState extends State<AllDrivers> {
  String _searchQuery = "";

  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> avatarColors = [
      Colors.blue.shade400,
      Colors.indigo.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.cyan.shade400,
    ];
    return avatarColors[hash.abs() % avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Fleet Directory", style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: "Search name or license...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF5F6F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('drivers').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs.where((d) {
                  final name = d['fullName'].toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (c, i) => const Divider(height: 1, indent: 80, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildDriverTile(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTile(String id, Map<String, dynamic> data) {
    final String fullName = data['fullName'] ?? 'Unnamed';
    final String status = data['status'] ?? 'pending_verification';
    final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: _getAvatarColor(fullName),
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("${data['vehicleType']} • ${data['licenseNumber']}"),
      trailing: _buildStatusDot(status),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => DriverDetail(driverId: id, driverData: data)),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color color = status == 'active' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status.split('_')[0].toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
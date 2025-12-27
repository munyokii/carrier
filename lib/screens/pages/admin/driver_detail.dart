import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverDetail extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const DriverDetail({super.key, required this.driverId, required this.driverData});

  @override
  State<DriverDetail> createState() => _DriverDetailState();
}

class _DriverDetailState extends State<DriverDetail> {
  bool _isUpdating = false;
  String? _selectedStationId;
  List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.driverData['stationId'];
    _loadStations();
  }

  Future<void> _loadStations() async {
    final snap = await FirebaseFirestore.instance.collection('stations').get();
    if (mounted) {
      setState(() {
        _stations = snap.docs.map((d) => {'id': d.id, 'name': d['stationName']}).toList();
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      String stationName = _stations.firstWhere(
        (s) => s['id'] == _selectedStationId,
        orElse: () => {'name': widget.driverData['stationName'] ?? 'Unknown Station'},
      )['name'];

      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).update({
        'status': status,
        'stationId': _selectedStationId,
        'stationName': stationName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Driver application ${status == 'active' ? 'Approved' : 'Rejected'}")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showFullScreenImage(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.driverData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Application Review", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(data),
            const Divider(height: 40),
            
            _buildSectionTitle("Contact Information"),
            _buildInfoTile("Email Address", data['email'], Icons.email_outlined),
            _buildInfoTile("Phone Number", data['phone'], Icons.phone_android_outlined),
            
            const SizedBox(height: 20),
            _buildSectionTitle("Professional Details"),
            _buildInfoTile("License Number", data['licenseNumber'], Icons.badge_outlined),
            _buildInfoTile("Vehicle Type", data['vehicleType'], Icons.local_shipping_outlined),
            _buildInfoTile("Experience", "${data['experienceYears']} Years", Icons.history),

            const SizedBox(height: 20),
            _buildSectionTitle("Station Assignment"),
            _buildStationSelector(),

            const SizedBox(height: 30),
            _buildSectionTitle("Uploaded Documents"),
            const Text("Tap images to verify details", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDocCard("Driver's License", data['licenseImageUrl'])),
                const SizedBox(width: 16),
                Expanded(child: _buildDocCard("Good Conduct", data['conductImageUrl'])),
              ],
            ),

            const SizedBox(height: 50),
            if (data['status'] == 'pending_verification') _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.blue.shade100,
          child: Text(data['fullName'][0].toUpperCase(), 
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['fullName'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildStatusBadge(data['status']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'active' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), 
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStationId,
          isExpanded: true,
          items: _stations.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']))).toList(),
          onChanged: _isUpdating ? null : (val) => setState(() => _selectedStationId = val),
        ),
      ),
    );
  }

  Widget _buildDocCard(String label, String? url) {
    return GestureDetector(
      onTap: () => url != null ? _showFullScreenImage(url, label) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[200],
              image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
            ),
            child: url == null ? const Center(child: Icon(Icons.broken_image)) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isUpdating ? null : () => _updateStatus('rejected'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _updateStatus('active'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUpdating 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("APPROVE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(), 
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.1)),
    );
  }
}
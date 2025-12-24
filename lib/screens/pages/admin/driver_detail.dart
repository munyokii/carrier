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

  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> avatarColors = [
      Colors.blue.shade400, Colors.indigo.shade400, Colors.teal.shade400,
      Colors.pink.shade400, Colors.orange.shade400, Colors.purple.shade400,
      Colors.cyan.shade400,
    ];
    return avatarColors[hash.abs() % avatarColors.length];
  }

  Future<void> _processApplication(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).update({'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Driver ${newStatus == 'active' ? 'Approved' : 'Rejected'}"),
            backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
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
            _buildProfileHeader(data),
            const Divider(height: 40),
            _buildSectionTitle("Registration Details"),
            _buildInfoTile("Full Name", data['fullName'], Icons.person_outline),
            _buildInfoTile("Email Address", data['email'], Icons.alternate_email),
            _buildInfoTile("Phone Number", data['phone'], Icons.phone_android),
            _buildInfoTile("Vehicle Type", data['vehicleType'], Icons.local_shipping_outlined),
            _buildInfoTile("License No.", data['licenseNumber'], Icons.badge_outlined),
            _buildInfoTile("Experience", "${data['experienceYears']} Years", Icons.history),
            const SizedBox(height: 30),
            _buildSectionTitle("Submitted Documents"),
            const Text("Tap images to enlarge", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildDocCard("Driver's License", data['licenseImageUrl'])),
                const SizedBox(width: 15),
                Expanded(child: _buildDocCard("Good Conduct Cert.", data['conductImageUrl'])),
              ],
            ),
            const SizedBox(height: 50),
            if (data['status'] == 'pending_verification')
              _buildActionButtons()
            else
              Center(child: Text("This application is already ${data['status'].toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    final String name = data['fullName'] ?? 'Unnamed';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: _getAvatarColor(name),
          child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildStatusBadge(data['status']),
          ],
        ),
      ],
    );
  }

  // InfoTile, DocCard, FullScreenImage, ActionButtons, SectionTitle, StatusBadge methods remain same as provided in previous context...
  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(String label, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => url != null ? _showFullScreenImage(url) : null,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[100],
              image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
            ),
            child: url == null ? const Center(child: Icon(Icons.broken_image_outlined)) : null,
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, width: double.infinity, height: double.infinity)),
            Positioned(
              top: 40, right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isUpdating ? null : () => _processApplication('rejected'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Reject Driver", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _processApplication('active'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUpdating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Approve Driver", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Colors.black54)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'active' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
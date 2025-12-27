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
  bool _isUpdating = false; // Now used in the UI
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
      // Find the name of the selected station for denormalization
      String stationName = _stations.firstWhere(
        (s) => s['id'] == _selectedStationId,
        orElse: () => {'name': 'Unknown Station'},
      )['name'];
      
      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).update({
        'status': status,
        'stationId': _selectedStationId,
        'stationName': stationName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Driver $status successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Review Application")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            title: const Text("Current Station"), 
            subtitle: Text(widget.driverData['stationName'] ?? "None")
          ),
          const Divider(),
          const Text("RE-ASSIGN STATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          
          DropdownButton<String>(
            value: _selectedStationId,
            isExpanded: true,
            hint: const Text("Select Station"),
            // Disable dropdown while updating
            onChanged: _isUpdating ? null : (val) => setState(() => _selectedStationId = val),
            items: _stations.map((s) => DropdownMenuItem(
              value: s['id'].toString(), 
              child: Text(s['name'])
            )).toList(),
          ),
          
          const SizedBox(height: 40),
          
          Row(
            children: [
              // Approval Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : () => _updateStatus('active'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _isUpdating 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text("APPROVE"),
                ),
              ),
              const SizedBox(width: 10),
              // Reject Button
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUpdating ? null : () => _updateStatus('rejected'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text("REJECT"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
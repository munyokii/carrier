import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class AddStation extends StatefulWidget {
  const AddStation({super.key});

  @override
  State<AddStation> createState() => _AddStationState();
}

class _AddStationState extends State<AddStation> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isFetchingLocation = false;

  // Controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedType = 'Hub';
  final List<String> _stationTypes = ['Hub', 'Depot', 'Sortation Center', 'Pickup Point'];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _longController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isFetchingLocation = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Please enable Location Services in settings.", Colors.orange);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permission denied.", Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied. Please enable them in settings.", Colors.red);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _latController.text = position.latitude.toString();
        _longController.text = position.longitude.toString();
      });
      _showSnackBar("Location coordinates fetched!", Colors.green);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveStation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latController.text.isEmpty || _longController.text.isEmpty) {
      _showSnackBar("Please provide GPS coordinates for the station.", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> stationData = {
        'stationName': _nameController.text.trim(),
        'stationCode': _codeController.text.trim().toUpperCase(),
        'stationType': _selectedType,
        'address': _addressController.text.trim(),
        'coordinates': GeoPoint(
          double.parse(_latController.text),
          double.parse(_longController.text),
        ),
        'managerName': _managerController.text.trim(),
        'contactPhone': _phoneController.text.trim(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('stations').add(stationData);

      if (mounted) {
        _showSnackBar("Station registered successfully!", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Submission failed: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add Carrier Station", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Basic Information", Icons.info_outline, primaryColor),
              _buildField("Station Name", _nameController, Icons.business),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField("Station Code", _codeController, Icons.qr_code)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown()),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader("Location", Icons.map_outlined, primaryColor),
              _buildField("Full Physical Address", _addressController, Icons.location_on),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField("Latitude", _latController, Icons.explore, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField("Longitude", _longController, Icons.explore, isNumber: true)),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                icon: _isFetchingLocation 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
                label: Text(_isFetchingLocation ? "Fetching GPS..." : "Use current coordinates"),
              ),

              const SizedBox(height: 32),
              _buildSectionHeader("Management Details", Icons.contact_phone_outlined, primaryColor),
              _buildField("Station Manager Name", _managerController, Icons.person),
              const SizedBox(height: 16),
              _buildField("Contact Phone", _phoneController, Icons.phone, isNumber: true),
              
              const SizedBox(height: 50),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveStation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Confirm & Create Station", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Row(
        children: [
          Container(
            width: 4, height: 24,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          items: _stationTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _selectedType = val!),
        ),
      ),
    );
  }
}
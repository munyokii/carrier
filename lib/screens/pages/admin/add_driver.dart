import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class AddDriver extends StatefulWidget {
  const AddDriver({super.key});

  @override
  State<AddDriver> createState() => _AddDriverState();
}

class _AddDriverState extends State<AddDriver> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true; // Visibility Toggle State

  // Relation & Data State
  String? _selectedStationId;
  String? _selectedStationName;
  List<Map<String, dynamic>> _stations = [];
  
  String _selectedVehicle = 'Van';
  final List<String> _vehicles = ['Motorbike', 'Van', 'Truck (Light)', 'Truck (Heavy)'];

  // Cloudinary Config
  final String _cloudName = const String.fromEnvironment('CLOUDINARY_NAME');
  final String _uploadPreset = const String.fromEnvironment('UPLOAD_PRESET');
  late CloudinaryPublic _cloudinary;

  File? _licenseImage;
  File? _conductImage;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stations').get();
      if (mounted) {
        setState(() {
          _stations = snapshot.docs.map((doc) => {
            'id': doc.id,
            'name': doc['stationName'],
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching stations: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 50
    );
    if (pickedFile != null) {
      setState(() {
        if (isLicense) {
          _licenseImage = File(pickedFile.path);
        } else {
          _conductImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<String?> _uploadToCloudinary(File file, String folder) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path, folder: "drivers/$folder"),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null || _conductImage == null) {
      _showSnackBar("Please upload documents", Colors.orange);
      return;
    }
    if (_selectedStationId == null) {
      _showSnackBar("Please assign a station", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;
      final String? licenseUrl = await _uploadToCloudinary(_licenseImage!, 'licenses');
      final String? conductUrl = await _uploadToCloudinary(_conductImage!, 'conduct');

      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'driverId': uid,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNumber': _licenseController.text.trim().toUpperCase(),
        'vehicleType': _selectedVehicle,
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'licenseImageUrl': licenseUrl,
        'conductImageUrl': conductUrl,
        'status': 'pending_verification',
        'stationId': _selectedStationId,
        'stationName': _selectedStationName,
        'role': 'driver',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Driver", style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PERSONAL DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              _buildField("Full Name", _nameController, Icons.person),
              const SizedBox(height: 16),
              _buildField("Email Address", _emailController, Icons.email),
              const SizedBox(height: 16),
              
              // Password Field with Toggle
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: "Account Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                validator: (v) => (v != null && v.length < 6) ? 'Min 6 characters' : null,
              ),

              const SizedBox(height: 32),
              const Text("LOGISTICS ASSIGNMENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              
              // Station & Vehicle Selection
              Row(
                children: [
                  Expanded(child: _buildStationDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildVehicleDropdown()),
                ],
              ),
              
              const SizedBox(height: 32),
              const Text("DOCUMENTATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              
              _buildUploadTile(
                label: "Driver's License (Front)",
                isUploaded: _licenseImage != null,
                onTap: () => _pickImage(true),
              ),
              const SizedBox(height: 12),
              _buildUploadTile(
                label: "Certificate of Good Conduct",
                isUploaded: _conductImage != null,
                onTap: () => _pickImage(false),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDriver,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Complete Registration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildField(String hint, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint, 
        prefixIcon: Icon(icon), 
        filled: true, 
        fillColor: Colors.grey[50], 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildStationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStationId,
          hint: const Text("Station"),
          isExpanded: true,
          items: _stations.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'], style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) {
            setState(() {
              _selectedStationId = val;
              _selectedStationName = _stations.firstWhere((s) => s['id'] == val)['name'];
            });
          },
        ),
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVehicle,
          isExpanded: true,
          items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) => setState(() => _selectedVehicle = val!),
        ),
      ),
    );
  }

  Widget _buildUploadTile({required String label, required bool isUploaded, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      tileColor: isUploaded ? Colors.green[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(isUploaded ? Icons.verified : Icons.cloud_upload_outlined, color: isUploaded ? Colors.green : Colors.blue),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(isUploaded ? "Change" : "Upload", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }
}
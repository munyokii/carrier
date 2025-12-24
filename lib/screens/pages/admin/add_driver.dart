import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart'; // Use for Cloudinary

class AddDriver extends StatefulWidget {
  const AddDriver({super.key});

  @override
  State<AddDriver> createState() => _AddDriverState();
}

class _AddDriverState extends State<AddDriver> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final String _cloudName = const String.fromEnvironment('CLOUDINARY_NAME'); 
  final String _uploadPreset = const String.fromEnvironment('UPLOAD_PRESET');

  late CloudinaryPublic _cloudinary;

  File? _licenseImage;
  File? _conductImage;
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();

  String _selectedVehicle = 'Van';
  final List<String> _vehicles = ['Motorbike', 'Van', 'Truck (Light)', 'Truck (Heavy)'];

  @override
  void initState() {
    super.initState();
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
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
        CloudinaryFile.fromFile(
          file.path,
          folder: "drivers/$folder",
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_licenseImage == null || _conductImage == null) {
      _showSnackBar("Please upload both required documents", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? licenseUrl = await _uploadToCloudinary(_licenseImage!, 'licenses');
      final String? conductUrl = await _uploadToCloudinary(_conductImage!, 'conduct');

      if (licenseUrl == null || conductUrl == null) {
        throw Exception("Image upload failed. Check your Cloudinary settings.");
      }

      await FirebaseFirestore.instance.collection('drivers').add({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNumber': _licenseController.text.trim().toUpperCase(),
        'vehicleType': _selectedVehicle,
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'licenseImageUrl': licenseUrl,
        'conductImageUrl': conductUrl,
        'status': 'pending_verification',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar("Driver Profile Created!", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Register Driver", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Personal Details", Icons.person_outline, primaryColor),
              _buildField("Full Name", _nameController, Icons.badge_outlined),
              const SizedBox(height: 16),
              _buildField("Email Address", _emailController, Icons.alternate_email, isEmail: true),
              const SizedBox(height: 16),
              _buildField("Phone Number", _phoneController, Icons.phone_android, isNumber: true),
              
              const SizedBox(height: 32),
              _buildSectionHeader("Professional Info", Icons.assignment_ind_outlined, Colors.indigo),
              _buildField("License Number", _licenseController, Icons.contact_emergency_outlined),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField("Years Experience", _experienceController, Icons.history, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown()),
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionHeader("Documents Verification", Icons.verified_user_outlined, Colors.teal),
              _buildUploadPlaceholder(
                label: "Driver's License (Front)",
                isUploaded: _licenseImage != null,
                onTap: () => _pickImage(true),
              ),
              const SizedBox(height: 12),
              _buildUploadPlaceholder(
                label: "Certificate of Good Conduct",
                isUploaded: _conductImage != null,
                onTap: () => _pickImage(false),
              ),

              const SizedBox(height: 50),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Save Driver Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController controller, IconData icon, {bool isNumber = false, bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDropdown() {
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

  Widget _buildUploadPlaceholder({required String label, required bool isUploaded, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isUploaded ? Colors.green.shade300 : Colors.grey.shade300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(15),
          color: isUploaded ? Colors.green.shade50 : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(isUploaded ? Icons.check_circle_outline : Icons.cloud_upload_outlined, color: isUploaded ? Colors.green : Colors.grey),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                isUploaded ? "Document Selected" : label, 
                style: TextStyle(color: isUploaded ? Colors.green.shade700 : Colors.grey, fontSize: 13)
              ),
            ),
            Text(isUploaded ? "Change" : "Upload", style: TextStyle(color: isUploaded ? Colors.grey : Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
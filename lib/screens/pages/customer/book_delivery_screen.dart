import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_settings/app_settings.dart';
import 'package:carrier/models/carrier_model.dart';

class BookDeliveryScreen extends StatefulWidget {
  final CarrierModel carrier;

  const BookDeliveryScreen({super.key, required this.carrier});

  @override
  State<BookDeliveryScreen> createState() => _BookDeliveryScreenState();
}

class _BookDeliveryScreenState extends State<BookDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();

  Position? _pickupLocation;
  Position? _deliveryLocation;
  bool _isLoadingPickup = false;
  bool _isLoadingDelivery = false;
  bool _isSubmitting = false;
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationForPickup() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDisabledDialog('pickup');
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog('pickup');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedForeverDialog();
      return;
    }

    setState(() {
      _isLoadingPickup = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);
        
        setState(() {
          _pickupLocation = position;
          _pickupAddressController.text = address;
          _isLoadingPickup = false;
        });
      } else {
        setState(() {
          _pickupLocation = position;
          _pickupAddressController.text = '${position.latitude}, ${position.longitude}';
          _isLoadingPickup = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPickup = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocationForDelivery() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDisabledDialog('delivery');
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog('delivery');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedForeverDialog();
      return;
    }

    setState(() {
      _isLoadingDelivery = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);
        
        setState(() {
          _deliveryLocation = position;
          _deliveryAddressController.text = address;
          _isLoadingDelivery = false;
        });
      } else {
        setState(() {
          _deliveryLocation = position;
          _deliveryAddressController.text = '${position.latitude}, ${position.longitude}';
          _isLoadingDelivery = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingDelivery = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.postalCode != null && place.postalCode!.isNotEmpty) {
      addressParts.add(place.postalCode!);
    }
    return addressParts.join(', ');
  }

  Future<void> _selectPickupDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _pickupDate = picked;
      });
    }
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _pickupTime = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickupLocation == null || _deliveryLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set pickup and delivery locations')),
      );
      return;
    }

    if (_pickupDate == null || _pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup date and time')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      DateTime pickupDateTime = DateTime(
        _pickupDate!.year, _pickupDate!.month, _pickupDate!.day,
        _pickupTime!.hour, _pickupTime!.minute,
      );

      double distance = Geolocator.distanceBetween(
        _pickupLocation!.latitude, _pickupLocation!.longitude,
        _deliveryLocation!.latitude, _deliveryLocation!.longitude,
      ) / 1000;

      // 1. Create the main booking document and get the reference
      DocumentReference bookingRef = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'carrierId': widget.carrier.id,
        'carrierName': widget.carrier.driverName,
        'vehicleType': widget.carrier.vehicleType,
        'pickupAddress': _pickupAddressController.text.trim(),
        'pickupLatitude': _pickupLocation!.latitude,
        'pickupLongitude': _pickupLocation!.longitude,
        'deliveryAddress': _deliveryAddressController.text.trim(),
        'deliveryLatitude': _deliveryLocation!.latitude,
        'deliveryLongitude': _deliveryLocation!.longitude,
        'description': _descriptionController.text.trim(),
        'weight': _weightController.text.trim().isNotEmpty
            ? double.tryParse(_weightController.text.trim())
            : null,
        'distance': distance,
        'pickupDateTime': Timestamp.fromDate(pickupDateTime),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add the initial status history (This triggers the Notification Badges)
      await bookingRef.collection('status_history').add({
        'status': 'pending',
        'message': 'New booking request for ${widget.carrier.driverName}',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'bookingId': bookingRef.id,
        'read': false,        // For the Customer badge
        'readByAdmin': false, // For the Admin badge
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to home
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Delivery'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carrier Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: primaryColor, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.carrier.driverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.carrier.vehicleType} • ${widget.carrier.vehicleNumber}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Pickup Section
              _buildSectionHeader('Pickup Location', Icons.location_on, primaryColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pickupAddressController,
                      decoration: InputDecoration(
                        labelText: 'Pickup Address',
                        hintText: 'Enter or select pickup address',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter pickup address';
                        }
                        return null;
                      },
                      readOnly: true,
                      onTap: () {
                        _getCurrentLocationForPickup();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.my_location, color: primaryColor),
                    onPressed: _isLoadingPickup ? null : _getCurrentLocationForPickup,
                    tooltip: 'Use current location',
                  ),
                ],
              ),
              if (_isLoadingPickup)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),

              const SizedBox(height: 24),

              // Pickup Date & Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectPickupDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Pickup Date',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _pickupDate == null
                              ? 'Select date'
                              : '${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year}',
                          style: TextStyle(
                            color: _pickupDate == null
                                ? Colors.grey[600]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectPickupTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Pickup Time',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _pickupTime == null
                              ? 'Select time'
                              : _pickupTime!.format(context),
                          style: TextStyle(
                            color: _pickupTime == null
                                ? Colors.grey[600]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Delivery Section
              _buildSectionHeader('Delivery Location', Icons.location_city, primaryColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryAddressController,
                      decoration: InputDecoration(
                        labelText: 'Delivery Address',
                        hintText: 'Enter or select delivery address',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter delivery address';
                        }
                        return null;
                      },
                      readOnly: true,
                      onTap: () {
                        _getCurrentLocationForDelivery();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.my_location, color: primaryColor),
                    onPressed: _isLoadingDelivery ? null : _getCurrentLocationForDelivery,
                    tooltip: 'Use current location',
                  ),
                ],
              ),
              if (_isLoadingDelivery)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),

              const SizedBox(height: 30),

              // Package Details Section
              _buildSectionHeader('Package Details', Icons.inventory, primaryColor),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(
                  labelText: 'Weight (tons)',
                  hintText: 'Optional',
                  prefixIcon: const Icon(Icons.scale),
                  suffixText: 'tons',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final weight = double.tryParse(value);
                    if (weight == null || weight <= 0) {
                      return 'Please enter a valid weight';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Package Description',
                  hintText: 'Describe your package (optional)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle),
                            SizedBox(width: 8),
                            Text(
                              'Submit Booking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _showLocationServiceDisabledDialog(String type) async {
    if (!mounted) return;
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Services Disabled',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Location services are turned off. Please enable location services to use your current location for the $type address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                AppSettings.openAppSettings(type: AppSettingsType.location);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog(String type) async {
    if (!mounted) return;
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Permission Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'You need to grant location permission to use your current location for the $type address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (type == 'pickup') {
                  _getCurrentLocationForPickup();
                } else {
                  _getCurrentLocationForDelivery();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedForeverDialog() async {
    if (!mounted) return;
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Permission Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Location permission was permanently denied. Please enable location permission in your device settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                AppSettings.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}


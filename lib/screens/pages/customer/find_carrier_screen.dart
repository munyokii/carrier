import 'dart:convert';
import 'dart:math'; 
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';      
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindCarrierScreen extends StatefulWidget {
  const FindCarrierScreen({super.key});

  @override
  State<FindCarrierScreen> createState() => _FindCarrierScreenState();
}

class _FindCarrierScreenState extends State<FindCarrierScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  Position? _currentPosition;
  List<Map<String, dynamic>> _allNearbyStations = []; 
  List<Map<String, dynamic>> _filteredStations = [];  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStations = _allNearbyStations.where((station) {
        String name = station['stationName'].toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = position);
      _fetchStations();
    }
  }

  Future<void> _fetchStations() async {
    if (_currentPosition == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('stations')
        .where('status', isEqualTo: 'active')
        .get();

    List<Map<String, dynamic>> tempStations = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final GeoPoint point = data['coordinates'];
      
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        point.latitude,
        point.longitude,
      );

      double distanceInKm = distanceInMeters / 1000;

      if (distanceInKm <= 30.0) {
        data['id'] = doc.id; 
        data['distance'] = distanceInKm;
        tempStations.add(data);
      }
    }

    tempStations.sort((a, b) => a['distance'].compareTo(b['distance']));

    if (mounted) {
      setState(() {
        _allNearbyStations = tempStations;
        _filteredStations = tempStations;
        _isLoading = false;
      });
    }
  }

  void _showBookingSheet(Map<String, dynamic> stationData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingBottomSheet(
        stationData: stationData,
        userLocation: _currentPosition!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.carrier',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 40, height: 40,
                          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                        ),
                        ..._filteredStations.map((data) {
                          GeoPoint point = data['coordinates'];
                          return Marker(
                            point: LatLng(point.latitude, point.longitude),
                            width: 50, height: 50,
                            child: GestureDetector(
                              onTap: () => _showBookingSheet(data),
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search stations by name...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 20, left: 0, right: 0,
            child: SizedBox(
              height: 180,
              child: _isLoading 
                ? const SizedBox.shrink()
                : _filteredStations.isEmpty 
                  ? _buildNoResultsFound()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredStations.length,
                      itemBuilder: (context, index) => _buildStationCard(_filteredStations[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        final GeoPoint point = data['coordinates'];
        _mapController.move(LatLng(point.latitude, point.longitude), 15.0);
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['stationType']?.toUpperCase() ?? "HUB", 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                Text("${data['distance'].toStringAsFixed(1)} km", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(data['stationName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(data['address'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _showBookingSheet(data),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("Book Delivery"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Text("No matching hubs within 30km.", style: TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _BookingBottomSheet extends StatefulWidget {
  final Map<String, dynamic> stationData;
  final Position userLocation;

  const _BookingBottomSheet({required this.stationData, required this.userLocation});

  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet> {
  final _itemController = TextEditingController();
  final _addressController = TextEditingController();
  final _weightController = TextEditingController(); 
  
  List<dynamic> _placePredictions = [];
  final String _googleMapsApiKey = "YOUR_GOOGLE_PLACES_API_KEY"; 
  final String _sessionToken = const Uuid().v4(); 

  String _selectedVehicle = 'Motorbike';
  bool _isSubmitting = false;

  String _generateTrackingNumber() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; 
    final random = Random();
    String code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return "SWFT-$code"; 
  }

  Future<void> _getPlacePredictions(String query) async {
    if (query.isEmpty) {
      setState(() => _placePredictions = []);
      return;
    }

    final String url = 
      "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_googleMapsApiKey&sessiontoken=$_sessionToken";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _placePredictions = data['predictions']);
      }
    } catch (e) {
      debugPrint("Autocomplete Error: $e");
    }
  }

  double _calculateBookingPrice(double distanceKm, String vehicleType) {
    double baseFare = 50.0;
    double perKmRate = 30.0;

    switch (vehicleType) {
      case 'Motorbike': perKmRate = 35.0; break;
      case 'Van': perKmRate = 80.0; baseFare = 200.0; break;
      case 'Truck': perKmRate = 150.0; baseFare = 500.0; break;
    }
    return baseFare + (distanceKm * perKmRate);
  }

  void _submitBooking() async {
    if (_isSubmitting) return;

    if (_itemController.text.isEmpty || _addressController.text.isEmpty || _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (!mounted) return;

      String userPhone = userDoc.data()?['phone'] ?? user.phoneNumber ?? "N/A";

      if (userPhone == "N/A") {
        setState(() => _isSubmitting = false);
        throw Exception("Phone number not found. Please update your profile.");
      }

      final String trackingId = _generateTrackingNumber();
      final double distance = widget.stationData['distance'];
      final double calculatedPrice = _calculateBookingPrice(distance, _selectedVehicle);

      final booking = BookingModel(
        id: '',
        userId: user.uid,
        stationId: widget.stationData['id'],
        stationName: widget.stationData['stationName'],
        trackingNumber: trackingId,
        customerPhone: userPhone,
        carrierId: '',
        carrierName: 'Searching...',
        vehicleType: _selectedVehicle,
        itemDescription: _itemController.text.trim(),
        weight: double.tryParse(_weightController.text) ?? 0.0,
        pickupAddress: widget.stationData['address'],
        pickupLocation: widget.stationData['coordinates'],
        deliveryAddress: _addressController.text.trim(),
        deliveryLocation: const GeoPoint(0, 0), 
        distance: distance,
        pickupDateTime: DateTime.now().add(const Duration(hours: 1)),
        status: 'pending',
        price: calculatedPrice,
        createdAt: DateTime.now(),
      );

      var bookingData = booking.toMap();
      bookingData['createdAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('bookings').add(bookingData);

      if (!mounted) return;

      Navigator.pop(context);
      _showSuccessDialog(trackingId); 

    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Booking Successful!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Your tracking number is:"),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blue)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 25, left: 25, right: 25, bottom: MediaQuery.of(context).viewInsets.bottom + 25),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text("Book to ${widget.stationData['stationName']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildInput("Item Description", _itemController, Icons.inventory_2_outlined),
            const SizedBox(height: 15),
            
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: "Package Weight",
                suffixText: "kg",
                prefixIcon: const Icon(Icons.fitness_center_outlined),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _addressController,
              onChanged: _getPlacePredictions,
              decoration: InputDecoration(
                hintText: "Delivery Destination",
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),

            if (_placePredictions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _placePredictions.length,
                  itemBuilder: (context, index) {
                    final prediction = _placePredictions[index];
                    return ListTile(
                      title: Text(prediction['description'], style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _addressController.text = prediction['description'];
                          _placePredictions = [];
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),
            const Text("Select Transport", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Motorbike', 'Van', 'Truck'].map((v) => ChoiceChip(
                label: Text(v),
                selected: _selectedVehicle == v,
                onSelected: (s) => setState(() => _selectedVehicle = v),
              )).toList(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBooking,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Booking...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon), filled: true, fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}
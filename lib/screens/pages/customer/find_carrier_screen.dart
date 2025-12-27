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
  Position? _currentPosition;
  
  // Changed to store data with its calculated distance for easier sorting
  List<Map<String, dynamic>> _nearbyStations = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
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

    List<Map<String, dynamic>> filteredList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final GeoPoint point = data['coordinates'];
      
      // 1. Calculate distance in meters
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        point.latitude,
        point.longitude,
      );

      double distanceInKm = distanceInMeters / 1000;

      // 2. Filter: Only include stations within 30km
      if (distanceInKm <= 30.0) {
        data['id'] = doc.id; // Store ID for booking
        data['distance'] = distanceInKm; // Store distance for sorting
        filteredList.add(data);
      }
    }

    // 3. Sort: Ascending (Closest to Furthest)
    filteredList.sort((a, b) => a['distance'].compareTo(b['distance']));

    if (mounted) {
      setState(() {
        _nearbyStations = filteredList;
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
        stationData: stationData, // Pass the Map instead of DocumentSnapshot
        userLocation: _currentPosition!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Layer
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
                        // Current Position Marker
                        Marker(
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 40, height: 40,
                          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                        ),
                        // Station Markers (Filtered)
                        ..._nearbyStations.map((data) {
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

          // Header Overlay (Back & Search)
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text("Hubs within 30km", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ],
            ),
          ),

          // Horizontal Carousel
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: SizedBox(
              height: 180,
              child: _isLoading 
                ? const SizedBox.shrink()
                : _nearbyStations.isEmpty 
                  ? _buildNoStationsFound()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _nearbyStations.length,
                      itemBuilder: (context, index) {
                        final data = _nearbyStations[index];
                        return _buildStationCard(data);
                      },
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                  child: Text(data['stationType'] ?? "Hub", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
                // Display calculated distance
                Text("${data['distance'].toStringAsFixed(1)} km", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 10),
            Text(data['stationName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(data['address'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _showBookingSheet(data),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Book Delivery"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNoStationsFound() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Text("No stations found within 30km of your location.", textAlign: TextAlign.center),
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
  String _selectedVehicle = 'Motorbike';
  bool _isSubmitting = false;

  void _submitBooking() async {
    if (_itemController.text.isEmpty || _addressController.text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    try {
      final booking = BookingModel(
        id: '', 
        userId: user.uid,
        stationId: widget.stationData['id'],
        stationName: widget.stationData['stationName'],
        carrierId: '',
        carrierName: 'Searching...',
        vehicleType: _selectedVehicle,
        itemDescription: _itemController.text.trim(),
        pickupAddress: widget.stationData['address'],
        pickupLocation: widget.stationData['coordinates'],
        deliveryAddress: _addressController.text.trim(),
        deliveryLocation: const GeoPoint(0, 0),
        distance: widget.stationData['distance'], // Use the distance we already calculated
        pickupDateTime: DateTime.now().add(const Duration(hours: 1)),
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('bookings').add(booking.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking request sent!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 25, left: 25, right: 25, bottom: MediaQuery.of(context).viewInsets.bottom + 25),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
          _buildInput("Delivery Destination", _addressController, Icons.location_on_outlined),
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
                : const Text("Confirm Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
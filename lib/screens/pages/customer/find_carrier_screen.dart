import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_settings/app_settings.dart';
import 'package:carrier/models/carrier_model.dart';
import 'package:carrier/screens/pages/customer/carrier_detail_screen.dart';

class FindCarrierScreen extends StatefulWidget {
  const FindCarrierScreen({super.key});

  @override
  State<FindCarrierScreen> createState() => _FindCarrierScreenState();
}

class _FindCarrierScreenState extends State<FindCarrierScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition;
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;
  bool _hasShownConsent = false;
  bool _isMapReady = false;
  List<Marker> _markers = [];
  List<CarrierModel> _carriers = [];
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoadingLocation = false;
        _locationPermissionDenied = true;
      });
      _showLocationServiceDisabledDialog();
      return;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Show consent dialog before requesting permission
      if (!_hasShownConsent) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationConsentDialog();
        return;
      }
      
      // User has seen consent, request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoadingLocation = false;
        _locationPermissionDenied = true;
      });
      _showPermissionDeniedForeverDialog();
      return;
    }

    // Permission granted, get location
    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      _getUserLocation();
    }
  }

  Future<void> _getUserLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userPosition = position;
        _isLoadingLocation = false;
        _locationPermissionDenied = false;
      });

      // Map will be moved in onMapReady callback when it's ready
      // Just load carriers here, map movement will happen automatically
      _loadAvailableCarriers(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationPermissionDenied = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLocationConsentDialog() async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.location_on, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We need your location to:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              SizedBox(height: 12),
              _ConsentItem(
                icon: Icons.map,
                text: 'Show nearby carrier vehicles on the map',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.straighten,
                text: 'Calculate distances to available carriers',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.navigation,
                text: 'Help you find the closest carrier for your delivery',
              ),
              SizedBox(height: 16),
              Text(
                'Your location is only used to find carriers and is not shared with third parties.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                setState(() {
                  _locationPermissionDenied = true;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Allow Location'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _hasShownConsent = true;
      });
      _checkLocationStatus();
    } else {
      setState(() {
        _locationPermissionDenied = true;
      });
    }
  }

  Future<void> _showLocationServiceDisabledDialog() async {
    if (!mounted) return;

    final primaryColor = Theme.of(context).colorScheme.primary;
    await showDialog(
      context: context,
      barrierDismissible: false,
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location services are turned off on your device. To find nearby carriers, please enable location services.',
              ),
              SizedBox(height: 16),
              Text(
                'You can enable it in your device settings.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog() async {
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
                  'Location Permission Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'You need to grant location permission to find nearby carriers. Please allow location access when prompted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkLocationStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location permission was permanently denied. To use this feature, you need to enable location permission in your device settings.',
              ),
              SizedBox(height: 12),
              Text(
                '1. Open Settings\n'
                '2. Go to App Permissions\n'
                '3. Enable Location permission for Carrier',
                style: TextStyle(fontSize: 14),
              ),
            ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAvailableCarriers(double userLat, double userLon) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('carriers')
          .where('isAvailable', isEqualTo: true)
          .get();

      List<CarrierModel> carriers = snapshot.docs.map((doc) {
        return CarrierModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Calculate distances and sort by proximity
      for (var carrier in carriers) {
        carrier.calculateDistance(userLat, userLon);
      }
      carriers.sort((a, b) => a.calculateDistance(userLat, userLon)
          .compareTo(b.calculateDistance(userLat, userLon)));

      _createMarkers(carriers, userLat, userLon);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading carriers: $e')),
        );
      }
    }
  }

  void _createMarkers(List<CarrierModel> carriers, double userLat, double userLon) {
    List<Marker> markers = [];

    // Add user location marker
    markers.add(
      Marker(
        point: latlong.LatLng(userLat, userLon),
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 24),
        ),
      ),
    );

    // Add carrier markers
    for (var carrier in carriers) {
      final distance = carrier.calculateDistance(userLat, userLon);
      markers.add(
        Marker(
          point: latlong.LatLng(carrier.latitude, carrier.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showCarrierDetails(carrier),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
    }

    setState(() {
      _carriers = carriers;
      _markers = markers;
    });
  }

  void _showCarrierDetails(CarrierModel carrier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarrierDetailScreen(carrier: carrier),
      ),
    );
  }


  void _moveToUserLocation() {
    if (_userPosition != null && _isMapReady) {
      _mapController.move(
        latlong.LatLng(_userPosition!.latitude, _userPosition!.longitude),
        _currentZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Carrier'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          _isLoadingLocation
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      const Text('Getting your location...'),
                    ],
                  ),
                )
              : _locationPermissionDenied || _userPosition == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Location access required',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please enable location services to find nearby carriers',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _checkLocationStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              AppSettings.openAppSettings(type: AppSettingsType.location);
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Open Settings'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: latlong.LatLng(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        ),
                        initialZoom: _currentZoom,
                        minZoom: 5.0,
                        maxZoom: 18.0,
                        onMapReady: () {
                          setState(() {
                            _isMapReady = true;
                          });
                          
                          // Move map to user location if we have it
                          if (_userPosition != null) {
                            _mapController.move(
                              latlong.LatLng(
                                _userPosition!.latitude,
                                _userPosition!.longitude,
                              ),
                              _currentZoom,
                            );
                          }
                          
                          // Load carriers
                          if (_userPosition != null) {
                            _loadAvailableCarriers(
                              _userPosition!.latitude,
                              _userPosition!.longitude,
                            );
                          }
                        },
                      ),
                      children: [
                        // Tile Layer - OpenStreetMap (Free)
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.carrier',
                          maxZoom: 19,
                        ),
                        // Marker Layer
                        MarkerLayer(
                          markers: _markers,
                        ),
                      ],
                    ),

          // Bottom Sheet with Carrier List
          if (_carriers.isNotEmpty && _userPosition != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Carriers (${_carriers.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              // Collapse bottom sheet (optional)
                            },
                          ),
                        ],
                      ),
                    ),
                    // Carrier List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _carriers.length > 5 ? 5 : _carriers.length,
                        itemBuilder: (context, index) {
                          final carrier = _carriers[index];
                          final distance = carrier.calculateDistance(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                          );
                          return _buildCarrierListItem(carrier, distance, primaryColor);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Action Buttons
          if (_userPosition != null)
            Positioned(
              right: 16,
              bottom: _carriers.isNotEmpty ? 270 : 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'my_location',
                    onPressed: _moveToUserLocation,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.my_location, color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'refresh',
                    onPressed: () {
                      if (_userPosition != null) {
                        _loadAvailableCarriers(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        );
                      }
                    },
                    backgroundColor: Colors.white,
                    child: Icon(Icons.refresh, color: primaryColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarrierListItem(CarrierModel carrier, double distance, Color primaryColor) {
    return InkWell(
      onTap: () => _showCarrierDetails(carrier),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Vehicle Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_shipping,
                color: primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Carrier Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    carrier.driverName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${carrier.vehicleType} • ${carrier.vehicleNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        carrier.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

// Helper widget for consent dialog items
class _ConsentItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConsentItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

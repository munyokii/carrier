import 'dart:math' as math;

class CarrierModel {
  final String id;
  final String driverName;
  final String vehicleType;
  final String vehicleNumber;
  final double latitude;
  final double longitude;
  final String? vehicleImage;
  final double rating;
  final int totalTrips;
  final bool isAvailable;
  final double? capacity; // in tons
  final List<String>? services;
  final String? phoneNumber;
  final String? email;
  final DateTime? lastUpdate;

  CarrierModel({
    required this.id,
    required this.driverName,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.latitude,
    required this.longitude,
    this.vehicleImage,
    this.rating = 0.0,
    this.totalTrips = 0,
    this.isAvailable = true,
    this.capacity,
    this.services,
    this.phoneNumber,
    this.email,
    this.lastUpdate,
  });

  // Calculate distance from user location (in km)
  double calculateDistance(double userLat, double userLon) {
    return _calculateDistance(latitude, longitude, userLat, userLon);
  }

  // Haversine formula to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Create CarrierModel from Firestore document
  factory CarrierModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CarrierModel(
      id: id,
      driverName: data['driverName'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      vehicleNumber: data['vehicleNumber'] ?? '',
      latitude: (data['location']?['latitude'] ?? data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['location']?['longitude'] ?? data['longitude'] ?? 0.0).toDouble(),
      vehicleImage: data['vehicleImage'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalTrips: data['totalTrips'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      capacity: data['capacity']?.toDouble(),
      services: data['services'] != null ? List<String>.from(data['services']) : null,
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      lastUpdate: data['lastUpdate']?.toDate(),
    );
  }

  // Convert CarrierModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'driverName': driverName,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'vehicleImage': vehicleImage,
      'rating': rating,
      'totalTrips': totalTrips,
      'isAvailable': isAvailable,
      'capacity': capacity,
      'services': services,
      'phoneNumber': phoneNumber,
      'email': email,
      'lastUpdate': lastUpdate,
    };
  }

  CarrierModel copyWith({
    String? id,
    String? driverName,
    String? vehicleType,
    String? vehicleNumber,
    double? latitude,
    double? longitude,
    String? vehicleImage,
    double? rating,
    int? totalTrips,
    bool? isAvailable,
    double? capacity,
    List<String>? services,
    String? phoneNumber,
    String? email,
    DateTime? lastUpdate,
  }) {
    return CarrierModel(
      id: id ?? this.id,
      driverName: driverName ?? this.driverName,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleImage: vehicleImage ?? this.vehicleImage,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      isAvailable: isAvailable ?? this.isAvailable,
      capacity: capacity ?? this.capacity,
      services: services ?? this.services,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}


import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';

class BookingService {
  final CollectionReference _bookingsRef = 
      FirebaseFirestore.instance.collection('bookings');

  String _generateTrackingNumber() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; 
    final random = Random();
    String code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return "SWFT-$code"; 
  }

  double _calculatePrice(double distanceKm, String vehicleType) {
    double baseFare = 50.0; // Base start price in KES
    double perKmRate = 30.0;

    switch (vehicleType) {
      case 'Motorbike':
        perKmRate = 35.0;
        break;
      case 'Van':
        perKmRate = 80.0;
        baseFare = 200.0;
        break;
      case 'Truck':
        perKmRate = 150.0;
        baseFare = 500.0;
        break;
    }
    return baseFare + (distanceKm * perKmRate);
  }

  Future<void> createBooking({
    required String userId,
    required String customerPhone, // ADDED THIS
    required String stationId,
    required String stationName,
    required String vehicleType,
    required String itemDescription,
    required String pickupAddress,
    required GeoPoint pickupLocation,
    required String deliveryAddress,
    required GeoPoint deliveryLocation,
    required double distance,
    required DateTime pickupDate,
    double? weight,
  }) async {
    try {
      final String newId = _bookingsRef.doc().id;
      final String trackingNumber = _generateTrackingNumber();
      final double totalPrice = _calculatePrice(distance, vehicleType);

      BookingModel newBooking = BookingModel(
        id: newId,
        userId: userId,
        trackingNumber: trackingNumber,
        customerPhone: customerPhone, // ADDED THIS
        stationId: stationId,
        stationName: stationName,
        carrierId: '',
        carrierName: 'Searching...', 
        vehicleType: vehicleType,
        itemDescription: itemDescription,
        pickupAddress: pickupAddress,
        pickupLocation: pickupLocation,
        deliveryAddress: deliveryAddress,
        deliveryLocation: deliveryLocation,
        distance: distance,
        pickupDateTime: pickupDate,
        weight: weight ?? 0.0,
        status: 'pending',
        price: totalPrice,
        createdAt: DateTime.now(),
      );

      // We use toMap() which now includes customerPhone
      await _bookingsRef.doc(newId).set(newBooking.toMap());
      
      // Optional: Create initial status history log
      await _bookingsRef.doc(newId).collection('status_history').add({
        'status': 'pending',
        'message': 'Booking created. Waiting for driver assignment.',
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Error creating booking: $e");
      rethrow;
    }
  }
}
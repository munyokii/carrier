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

  Future<void> createBooking({
    required String userId,
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

      BookingModel newBooking = BookingModel(
        id: newId,
        userId: userId,
        trackingNumber: trackingNumber,
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
        createdAt: DateTime.now(),
      );

      await _bookingsRef.doc(newId).set(newBooking.toMap());
      
    } catch (e) {
      print("Error creating booking: $e");
      rethrow;
    }
  }
}
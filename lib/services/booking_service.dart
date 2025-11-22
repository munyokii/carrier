import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';

class BookingService {
  // Reference to the Firestore collection
  final CollectionReference _bookingsRef = 
      FirebaseFirestore.instance.collection('bookings');

  /// Creates a new booking in Firestore
  Future<void> createBooking({
    required String userId,
    required String carrierId,
    required String carrierName,
    required String vehicleType,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String deliveryAddress,
    required double deliveryLat,
    required double deliveryLng,
    required double distance,
    required DateTime pickupDate,
    String? description,
    double? weight,
  }) async {
    try {
      // 1. Generate a new Document ID automatically
      String newId = _bookingsRef.doc().id;

      // 2. Create the BookingModel instance
      BookingModel newBooking = BookingModel(
        id: newId,
        userId: userId,
        carrierId: carrierId,
        carrierName: carrierName,
        vehicleType: vehicleType,
        pickupAddress: pickupAddress,
        pickupLatitude: pickupLat,
        pickupLongitude: pickupLng,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLat,
        deliveryLongitude: deliveryLng,
        distance: distance,
        pickupDateTime: pickupDate,
        description: description,
        weight: weight,
        status: 'pending', // Default status
        createdAt: DateTime.now(),
      );

      // 3. Save to Firestore using the toMap() method
      await _bookingsRef.doc(newId).set(newBooking.toMap());
      
      print("Booking created successfully with ID: $newId");
      
    } catch (e) {
      print("Error creating booking: $e");
      rethrow; // Pass the error up to the UI to handle
    }
  }
}
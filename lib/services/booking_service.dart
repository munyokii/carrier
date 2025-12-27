import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';

class BookingService {
  final CollectionReference _bookingsRef = 
      FirebaseFirestore.instance.collection('bookings');

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
      String newId = _bookingsRef.doc().id;

      BookingModel newBooking = BookingModel(
        id: newId,
        userId: userId,
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
        weight: weight,
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
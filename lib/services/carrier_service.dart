import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Add if using context/snackbars
import 'package:carrier/models/carrier_model.dart'; // Assuming your model is in carrier_model.dart

class CarrierService {
  // Reference to the 'carriers' collection
  final CollectionReference _carriersRef = 
      FirebaseFirestore.instance.collection('carriers');

  /// 🚛 1. Create/Add a New Carrier
  /// 
  /// Uses the CarrierModel's toFirestore() method.
  Future<void> addCarrier(CarrierModel carrier) async {
    try {
      // Note: We use .doc(carrier.id).set() because the ID is part of the model 
      // and typically set when the user/carrier account is created.
      await _carriersRef.doc(carrier.id).set(carrier.toFirestore());
      print("Carrier ${carrier.id} added successfully.");
    } catch (e) {
      print("Error adding carrier: $e");
      // Optionally handle specific Firestore exceptions
      rethrow; 
    }
  }
  
  /// 📍 2. Update a Carrier's Location and Availability
  /// 
  /// Use update() for partial updates, which is ideal for changing location/status.
  Future<void> updateCarrierLocation({
    required String carrierId,
    required double newLatitude,
    required double newLongitude,
    bool? isAvailable,
  }) async {
    try {
      final updateData = {
        'location': {
          'latitude': newLatitude,
          'longitude': newLongitude,
        },
        'lastUpdate': FieldValue.serverTimestamp(), // Firestore updates the time
      };

      if (isAvailable != null) {
        updateData['isAvailable'] = isAvailable;
      }

      await _carriersRef.doc(carrierId).update(updateData);
      print("Location updated for carrier: $carrierId");
    } catch (e) {
      print("Error updating location: $e");
      rethrow;
    }
  }

  /// 🔎 3. Get a Single Carrier by ID
  Future<CarrierModel?> getCarrier(String id) async {
    try {
      final docSnapshot = await _carriersRef.doc(id).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Use the fromFirestore factory to convert the data map
        return CarrierModel.fromFirestore(
            docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
      }
      return null;
    } catch (e) {
      print("Error fetching carrier: $e");
      return null;
    }
  }

  // --- Real-time Location Stream ---
  
  /// 📡 4. Stream a Single Carrier's Document
  Stream<CarrierModel?> streamCarrier(String id) {
    return _carriersRef.doc(id).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return CarrierModel.fromFirestore(
            snapshot.data() as Map<String, dynamic>, snapshot.id);
      }
      return null;
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingModel {
  final String id;
  final String userId;
  
  // --- Station Specific Fields ---
  final String stationId;
  final String stationName;
  
  // --- Delivery Details ---
  final String carrierId;
  final String carrierName;
  final String vehicleType;
  final String itemDescription;
  
  // --- Location Data ---
  final String pickupAddress;
  final GeoPoint pickupLocation;
  final String deliveryAddress;
  final GeoPoint deliveryLocation;
  
  // --- Metrics ---
  final double? weight;
  final double distance;
  final DateTime pickupDateTime;
  final String status; // pending, accepted, in_transit, delivered, cancelled
  final DateTime createdAt;
  
  // --- Real-time Tracking ---
  final GeoPoint? currentCarrierLocation;

  BookingModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.carrierId,
    required this.carrierName,
    required this.vehicleType,
    required this.itemDescription,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.deliveryAddress,
    required this.deliveryLocation,
    this.weight,
    required this.distance,
    required this.pickupDateTime,
    required this.status,
    required this.createdAt,
    this.currentCarrierLocation,
  });

  // --- Firestore Serialization ---

  factory BookingModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BookingModel(
      id: id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      stationName: data['stationName'] ?? '',
      carrierId: data['carrierId'] ?? '',
      carrierName: data['carrierName'] ?? 'Searching for Driver...',
      vehicleType: data['vehicleType'] ?? '',
      itemDescription: data['itemDescription'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      pickupLocation: data['pickupLocation'] as GeoPoint,
      deliveryAddress: data['deliveryAddress'] ?? '',
      deliveryLocation: data['deliveryLocation'] as GeoPoint,
      weight: data['weight']?.toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      pickupDateTime: (data['pickupDateTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      currentCarrierLocation: data['currentCarrierLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stationId': stationId,
      'stationName': stationName,
      'carrierId': carrierId,
      'carrierName': carrierName,
      'vehicleType': vehicleType,
      'itemDescription': itemDescription,
      'pickupAddress': pickupAddress,
      'pickupLocation': pickupLocation,
      'deliveryAddress': deliveryAddress,
      'deliveryLocation': deliveryLocation,
      'weight': weight,
      'distance': distance,
      'pickupDateTime': Timestamp.fromDate(pickupDateTime),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentCarrierLocation': currentCarrierLocation,
    };
  }

  // --- UI HELPERS (Re-added to fix Dashboard Errors) ---

  /// Formats the raw status string for display
  String get statusDisplayName {
    switch (status) {
      case 'pending': return 'Pending';
      case 'accepted': return 'Accepted';
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status[0].toUpperCase() + status.substring(1);
    }
  }

  /// Provides the integer index for progress bars
  int get statusProgress {
    switch (status) {
      case 'pending': return 0;
      case 'accepted': return 1;
      case 'in_transit': return 2;
      case 'delivered': return 3;
      case 'cancelled': return -1;
      default: return 0;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'in_transit': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending': return Icons.access_time;
      case 'accepted': return Icons.assignment_turned_in;
      case 'in_transit': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingModel {
  final String id;
  final String userId;
  final String carrierId;
  final String carrierName;
  final String vehicleType;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? description;
  final double? weight;
  final double distance;
  final DateTime pickupDateTime;
  final String status; // pending, accepted, in_transit, delivered, cancelled
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? currentLocation; // Optional: current location during transit
  final double? currentLatitude; // Optional: current carrier location
  final double? currentLongitude; // Optional: current carrier location

  BookingModel({
    required this.id,
    required this.userId,
    required this.carrierId,
    required this.carrierName,
    required this.vehicleType,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.description,
    this.weight,
    required this.distance,
    required this.pickupDateTime,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.currentLocation,
    this.currentLatitude,
    this.currentLongitude,
  });

  // --- Firestore Serialization Methods ---

  // 1. Create BookingModel from Firestore document (Reading Data)
  factory BookingModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BookingModel(
      id: id,
      userId: data['userId'] ?? '',
      carrierId: data['carrierId'] ?? '',
      carrierName: data['carrierName'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      pickupLatitude: (data['pickupLatitude'] ?? 0.0).toDouble(),
      pickupLongitude: (data['pickupLongitude'] ?? 0.0).toDouble(),
      deliveryAddress: data['deliveryAddress'] ?? '',
      deliveryLatitude: (data['deliveryLatitude'] ?? 0.0).toDouble(),
      deliveryLongitude: (data['deliveryLongitude'] ?? 0.0).toDouble(),
      description: data['description'],
      weight: data['weight']?.toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      // Handle Timestamp to DateTime conversion
      pickupDateTime: (data['pickupDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      // Handle Timestamp to DateTime conversion
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      currentLocation: data['currentLocation'],
      currentLatitude: data['currentLatitude']?.toDouble(),
      currentLongitude: data['currentLongitude']?.toDouble(),
    );
  }

  // 2. Convert BookingModel to a Map for Firestore (Writing Data)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'carrierId': carrierId,
      'carrierName': carrierName,
      'vehicleType': vehicleType,
      'pickupAddress': pickupAddress,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'description': description,
      'weight': weight,
      'distance': distance,
      // Convert DateTime to Firestore Timestamp
      'pickupDateTime': Timestamp.fromDate(pickupDateTime),
      'status': status,
      // Convert DateTime to Firestore Timestamp
      'createdAt': Timestamp.fromDate(createdAt),
      // Only convert if not null
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'currentLocation': currentLocation,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
    };
  }

  // --- Utility Getters (UI Logic) ---

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  int get statusProgress {
    switch (status) {
      case 'pending':
        return 0;
      case 'accepted':
        return 1;
      case 'in_transit':
        return 2;
      case 'delivered':
        return 3;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingModel {
  final String id;
  final String userId;
  final String trackingNumber; // NEW FIELD
  final String stationId;
  final String stationName;
  final String carrierId;
  final String carrierName;
  final String vehicleType;
  final String itemDescription;
  final double weight;
  final String pickupAddress;
  final GeoPoint pickupLocation;
  final String deliveryAddress;
  final GeoPoint deliveryLocation;
  final double distance;
  final DateTime pickupDateTime;
  final String status;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.userId,
    required this.trackingNumber, // ADD TO CONSTRUCTOR
    required this.stationId,
    required this.stationName,
    required this.carrierId,
    required this.carrierName,
    required this.vehicleType,
    required this.itemDescription,
    required this.weight,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.deliveryAddress,
    required this.deliveryLocation,
    required this.distance,
    required this.pickupDateTime,
    required this.status,
    required this.createdAt,
  });

  // Convert Firestore Map to Model
  factory BookingModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return BookingModel(
      id: docId,
      userId: json['userId'] ?? '',
      trackingNumber: json['trackingNumber'] ?? 'N/A', // FETCH FROM DB
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      carrierId: json['carrierId'] ?? '',
      carrierName: json['carrierName'] ?? 'Searching...',
      vehicleType: json['vehicleType'] ?? '',
      itemDescription: json['itemDescription'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      pickupAddress: json['pickupAddress'] ?? '',
      pickupLocation: json['pickupLocation'] ?? const GeoPoint(0, 0),
      deliveryAddress: json['deliveryAddress'] ?? '',
      deliveryLocation: json['deliveryLocation'] ?? const GeoPoint(0, 0),
      distance: (json['distance'] ?? 0).toDouble(),
      pickupDateTime: (json['pickupDateTime'] as Timestamp).toDate(),
      status: json['status'] ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convert Model to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'trackingNumber': trackingNumber, // SAVE TO DB
      'stationId': stationId,
      'stationName': stationName,
      'carrierId': carrierId,
      'carrierName': carrierName,
      'vehicleType': vehicleType,
      'itemDescription': itemDescription,
      'weight': weight,
      'pickupAddress': pickupAddress,
      'pickupLocation': pickupLocation,
      'deliveryAddress': deliveryAddress,
      'deliveryLocation': deliveryLocation,
      'distance': distance,
      'pickupDateTime': pickupDateTime,
      'status': status,
      'createdAt': createdAt,
    };
  }

  // UI Helpers (Status Colors/Icons)
  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'in_transit': return Colors.blue;
      case 'delivered': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  int get statusProgress {
    switch (status) {
      case 'pending': return 0;
      case 'accepted': return 1;
      case 'in_transit': return 2;
      case 'delivered': return 3;
      default: return 0;
    }
  }

  String get statusDisplayName => status.replaceAll('_', ' ').toUpperCase();
  IconData get statusIcon => status == 'delivered' ? Icons.check_circle : Icons.local_shipping;
}
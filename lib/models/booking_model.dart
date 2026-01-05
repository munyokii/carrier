import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingModel {
  final String id;
  final String userId;
  final String trackingNumber;
  final String customerPhone;
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
  final double price;

  BookingModel({
    required this.id,
    required this.userId,
    required this.trackingNumber,
    required this.customerPhone,
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
    required this.price,
  });

  factory BookingModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return BookingModel(
      id: docId,
      userId: json['userId'] ?? '',
      trackingNumber: json['trackingNumber'] ?? 'N/A',
      customerPhone: json['customerPhone'] ?? '',
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
      pickupDateTime: (json['pickupDateTime'] is Timestamp) 
          ? (json['pickupDateTime'] as Timestamp).toDate() 
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      price: (json['price'] ?? 0.0).toDouble(),
      createdAt: (json['createdAt'] is Timestamp) 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'trackingNumber': trackingNumber,
      'customerPhone': customerPhone,
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
      'price': price,
      'createdAt': createdAt,
    };
  }

  
  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'out_for_delivery': return Colors.blueAccent;
      case 'delivered': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  int get statusProgress {
    switch (status) {
      case 'pending': return 0;
      case 'accepted': return 1;
      case 'out_for_delivery': return 2;
      case 'delivered': return 3;
      default: return 0;
    }
  }

  String get statusDisplayName => status.replaceAll('_', ' ').toUpperCase();
  
  IconData get statusIcon {
    switch (status) {
      case 'delivered': return Icons.verified;
      case 'out_for_delivery': return Icons.directions_bike;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.local_shipping;
    }
  }
}
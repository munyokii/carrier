import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

class PackageDetailScreen extends StatefulWidget {
  final String bookingId;

  const PackageDetailScreen({super.key, required this.bookingId});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  BookingModel? _booking;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _booking = BookingModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading package details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Package Details'),
        ),
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Package Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Package not found'),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Details'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final updatedBooking = BookingModel.fromFirestore(
              snapshot.data!.data() as Map<String, dynamic>,
              snapshot.data!.id,
            );
            _booking = updatedBooking;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _booking!.statusColor.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: _booking!.statusColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _booking!.statusIcon,
                        size: 48,
                        color: _booking!.statusColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _booking!.statusDisplayName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _booking!.statusColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProgressIndicator(_booking!, primaryColor),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carrier Info
                      _buildInfoCard(
                        context: context,
                        primaryColor: primaryColor,
                        title: 'Carrier Information',
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.person,
                              label: 'Driver Name',
                              value: _booking!.carrierName,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              icon: Icons.local_shipping,
                              label: 'Vehicle Type',
                              value: _booking!.vehicleType,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Route Information
                      _buildInfoCard(
                        context: context,
                        primaryColor: primaryColor,
                        title: 'Route Information',
                        child: Column(
                          children: [
                            // Pickup
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pickup Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _booking!.pickupAddress,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Date: ${dateFormat.format(_booking!.pickupDateTime)} ${timeFormat.format(_booking!.pickupDateTime)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Arrow
                            Row(
                              children: [
                                const SizedBox(width: 20),
                                Icon(Icons.arrow_downward, color: Colors.grey[400]),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Delivery
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_city,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Delivery Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _booking!.deliveryAddress,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Package Details
                      if (_booking!.description != null || _booking!.weight != null)
                        _buildInfoCard(
                          context: context,
                          primaryColor: primaryColor,
                          title: 'Package Details',
                          child: Column(
                            children: [
                              if (_booking!.weight != null) ...[
                                _buildInfoRow(
                                  icon: Icons.scale,
                                  label: 'Weight',
                                  value: '${_booking!.weight} tons',
                                ),
                                if (_booking!.description != null)
                                  const Divider(height: 24),
                              ],
                              if (_booking!.description != null)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.description,
                                        size: 20, color: Colors.grey[600]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Description',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _booking!.description!,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Booking Information
                      _buildInfoCard(
                        context: context,
                        primaryColor: primaryColor,
                        title: 'Booking Information',
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: '${_booking!.distance.toStringAsFixed(1)} km',
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              label: 'Booking Date',
                              value: dateFormat.format(_booking!.createdAt),
                            ),
                            if (_booking!.updatedAt != null) ...[
                              const Divider(height: 24),
                              _buildInfoRow(
                                icon: Icons.update,
                                label: 'Last Updated',
                                value: dateFormat.format(_booking!.updatedAt!),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required Color primaryColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(BookingModel booking, Color primaryColor) {
    final steps = ['Pending', 'Accepted', 'In Transit', 'Delivered'];
    final currentStep = booking.statusProgress;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final isActive = index <= currentStep && currentStep >= 0;
            final isCurrent = index == currentStep;

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? (isCurrent ? booking.statusColor : Colors.green)
                          : Colors.grey[300],
                      border: Border.all(
                        color: isActive
                            ? (isCurrent ? booking.statusColor : Colors.green)
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isActive
                        ? Icon(
                            isCurrent ? booking.statusIcon : Icons.check,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: isActive && index < currentStep
                            ? Colors.green
                            : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.map((step) {
            return Expanded(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


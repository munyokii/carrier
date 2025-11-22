import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carrier/models/carrier_model.dart';
import 'package:carrier/screens/pages/book_delivery_screen.dart';

class CarrierDetailScreen extends StatelessWidget {
  final CarrierModel carrier;

  const CarrierDetailScreen({super.key, required this.carrier});

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty) {
      return;
    }
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: primaryColor.withOpacity(0.1),
                child: carrier.vehicleImage != null
                    ? Image.network(
                        carrier.vehicleImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(primaryColor);
                        },
                      )
                    : _buildPlaceholderImage(primaryColor),
              ),
              title: Text(
                carrier.driverName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Card
                  _buildInfoCard(
                    context: context,
                    primaryColor: primaryColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.local_shipping,
                          label: 'Vehicle Type',
                          value: carrier.vehicleType,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.confirmation_number,
                          label: 'Vehicle Number',
                          value: carrier.vehicleNumber,
                        ),
                        if (carrier.capacity != null) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.inventory,
                            label: 'Capacity',
                            value: '${carrier.capacity} tons',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Rating and Trips Card
                  _buildInfoCard(
                    context: context,
                    primaryColor: primaryColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.star,
                          label: 'Rating',
                          value: carrier.rating.toStringAsFixed(1),
                          color: Colors.amber,
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        _buildStatItem(
                          icon: Icons.local_shipping,
                          label: 'Total Trips',
                          value: carrier.totalTrips.toString(),
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),

                  if (carrier.services != null && carrier.services!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    // Services Card
                    _buildInfoCard(
                      context: context,
                      primaryColor: primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Services Offered',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: carrier.services!.map((service) {
                              return Chip(
                                label: Text(service),
                                backgroundColor: primaryColor.withOpacity(0.1),
                                labelStyle: TextStyle(color: primaryColor),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (carrier.phoneNumber != null || carrier.email != null) ...[
                    const SizedBox(height: 20),
                    // Contact Card
                    _buildInfoCard(
                      context: context,
                      primaryColor: primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (carrier.phoneNumber != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.phone, color: primaryColor),
                              title: const Text('Phone'),
                              subtitle: Text(carrier.phoneNumber!),
                              trailing: IconButton(
                                icon: Icon(Icons.call, color: primaryColor),
                                onPressed: () => _makePhoneCall(carrier.phoneNumber),
                              ),
                            ),
                          if (carrier.email != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.email, color: primaryColor),
                              title: const Text('Email'),
                              subtitle: Text(carrier.email!),
                              trailing: IconButton(
                                icon: Icon(Icons.send, color: primaryColor),
                                onPressed: () => _sendEmail(carrier.email),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Book Delivery Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDeliveryScreen(carrier: carrier),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_shopping_cart),
                          SizedBox(width: 8),
                          Text(
                            'Book Pickup & Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(Color primaryColor) {
    return Container(
      color: primaryColor.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.local_shipping,
          size: 100,
          color: primaryColor.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required Color primaryColor,
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
      child: child,
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}


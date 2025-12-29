import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class ShipmentDetail extends StatefulWidget {
  final BookingModel booking;
  const ShipmentDetail({super.key, required this.booking});

  @override
  State<ShipmentDetail> createState() => _ShipmentDetailState();
}

class _ShipmentDetailState extends State<ShipmentDetail> {
  bool _isUpdating = false;

  // 1. CALL CUSTOMER LOGIC - Fixed typo here
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showSnackBar("Could not open phone dialer", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error launching dialer", Colors.red);
    }
  }

  // 2. DATABASE UPDATE LOGIC
  Future<void> _updateStatus(String newStatus, String logMessage) async {
    setState(() => _isUpdating = true);
    
    final batch = FirebaseFirestore.instance.batch();
    final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id);
    final historyRef = bookingRef.collection('status_history').doc();

    batch.update(bookingRef, {'status': newStatus});
    batch.set(historyRef, {
      'status': newStatus,
      'message': logMessage,
      'timestamp': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      if (mounted) {
        _showSnackBar("Shipment marked as ${newStatus.replaceAll('_', ' ')}", Colors.green);
        if (newStatus == 'delivered') Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // 3. QR SCANNER MODAL
  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text("Scan Package QR Code", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Verify the Tracking ID on the label", 
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue == widget.booking.trackingNumber) {
                        Navigator.pop(context); // Close scanner
                        _updateStatus('delivered', "Package verified via QR scan. Delivery completed.");
                      } else {
                        debugPrint("Wrong QR Code: ${barcode.rawValue}");
                      }
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text("Target: ${widget.booking.trackingNumber}", 
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.booking.status;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Order Details", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(status, theme),
                  const SizedBox(height: 20),
                  _buildAddressCard(),
                  const SizedBox(height: 20),
                  _buildItemCard(),
                ],
              ),
            ),
          ),
          _buildBottomAction(status, theme),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            "CURRENT STATUS: ${status.toUpperCase().replaceAll('_', ' ')}",
            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _addressRow(Icons.radio_button_checked, "Pickup Location", widget.booking.stationName, Colors.blue),
            const Padding(
              padding: EdgeInsets.only(left: 11),
              child: SizedBox(height: 24, child: VerticalDivider(thickness: 1.5)),
            ),
            Row(
              children: [
                Expanded(
                  child: _addressRow(Icons.location_on, "Delivery Address", widget.booking.deliveryAddress, Colors.orange),
                ),
                Material(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    onPressed: () => _makePhoneCall(widget.booking.customerPhone),
                    icon: const Icon(Icons.phone, color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SHIPMENT CONTENTS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.booking.itemDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Tracking: ${widget.booking.trackingNumber}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text("${widget.booking.weight}kg", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(String status, ThemeData theme) {
    bool isOut = status == 'out_for_delivery';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: isOut ? Colors.green : theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        icon: _isUpdating 
          ? const SizedBox.shrink() 
          : Icon(isOut ? Icons.qr_code_scanner : Icons.local_shipping),
        onPressed: _isUpdating ? null : () {
          if (status == 'accepted') {
            _updateStatus('out_for_delivery', "Driver started the delivery journey.");
          } else if (isOut) {
            _openScanner();
          }
        },
        label: _isUpdating 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              isOut ? "SCAN QR TO COMPLETE" : "START DELIVERY",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
      ),
    );
  }
}
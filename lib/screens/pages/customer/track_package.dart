import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TrackPackageScreen extends StatefulWidget {
  const TrackPackageScreen({super.key});

  @override
  State<TrackPackageScreen> createState() => _TrackPackageScreenState();
}

class _TrackPackageScreenState extends State<TrackPackageScreen> {
  final TextEditingController _idController = TextEditingController();
  String? _searchId;

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? "";
                  if (code.isNotEmpty) {
                    setState(() {
                      _idController.text = code.toUpperCase();
                      _searchId = code.toUpperCase();
                    });
                    Navigator.pop(context);
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text("Align QR Code within the frame",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Track Package", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _searchId == null 
              ? _buildWaitingState() 
              : _buildTrackingTimeline(_searchId!),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Enter or Scan tracking number", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "e.g. SWFT-ABC123",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.tag),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                      onPressed: _openScanner,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_idController.text.isNotEmpty) {
                    setState(() {
                      _searchId = _idController.text.trim().toUpperCase();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor, 
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(String trackingNum) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('trackingNumber', isEqualTo: trackingNum)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildErrorState();
        }

        final doc = snapshot.data!.docs.first;
        final booking = BookingModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);

        return ListView(
          padding: const EdgeInsets.all(25),
          children: [
            _buildPackageSummary(booking),
            const SizedBox(height: 30),
            const Text("JOURNEY LOG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 20),
            _buildTimelineStep("Ordered", "Package request received", booking.createdAt, true),
            _buildTimelineStep("Accepted", "Driver ${booking.carrierName} assigned", null, booking.statusProgress >= 1),
            _buildTimelineStep("In Transit", "Carrier is moving to destination", null, booking.statusProgress >= 2),
            _buildTimelineStep("Delivered", "Package reached destination", null, booking.statusProgress >= 3),
          ],
        );
      },
    );
  }

  Widget _buildTimelineStep(String title, String desc, DateTime? time, bool isDone) {
    Color color = isDone ? Theme.of(context).primaryColor : Colors.grey[300]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
            ),
            Container(width: 2, height: 50, color: color.withOpacity(0.3)),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.black : Colors.grey)),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (time != null) Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontSize: 10, color: Colors.blue)),
              const SizedBox(height: 20),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPackageSummary(BookingModel booking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        border: Border.all(color: Colors.grey[100]!)
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 40, color: Colors.blueGrey),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.itemDescription, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Tracking ID: ${booking.trackingNumber}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
              const SizedBox(width: 5),
              Expanded(child: Text(booking.deliveryAddress, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_searching, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("Ready to track your package?", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.redAccent),
          const SizedBox(height: 15),
          const Text("Tracking ID not found.", style: TextStyle(fontWeight: FontWeight.bold)),
          const Text("Please check the ID and try again.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
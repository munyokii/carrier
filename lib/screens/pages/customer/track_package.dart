import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackPackageScreen extends StatefulWidget {
  const TrackPackageScreen({super.key});

  @override
  State<TrackPackageScreen> createState() => _TrackPackageScreenState();
}

class _TrackPackageScreenState extends State<TrackPackageScreen> {
  final TextEditingController _idController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _searchId;
  bool _showSuggestions = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _idController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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
                      _showSuggestions = false;
                    });
                    Navigator.pop(context);
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              top: 20, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
        title: const Text("Track My Package", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showSuggestions = false),
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: Stack(
                children: [
                  _searchId == null 
                      ? _buildWaitingState() 
                      : _buildTrackingTimeline(_searchId!),
                  if (_showSuggestions) _buildActiveBookingsOverlay(),
                ],
              ),
            ),
          ],
        ),
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
          const Text("Enter or Scan your tracking number", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  focusNode: _searchFocus,
                  onTap: () => setState(() => _showSuggestions = true),
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
                      _showSuggestions = false;
                      _searchFocus.unfocus();
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


  Widget _buildActiveBookingsOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.05),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        constraints: const BoxConstraints(maxHeight: 300),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: _currentUser?.uid)
              .where('status', whereIn: ['pending', 'accepted', 'out_for_delivery'])
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No active bookings found.", style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                  title: Text(data['trackingNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['itemDescription'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () {
                    setState(() {
                      _idController.text = data['trackingNumber'];
                      _searchId = data['trackingNumber'];
                      _showSuggestions = false;
                    });
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackingTimeline(String trackingNum) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('trackingNumber', isEqualTo: trackingNum)
          .where('userId', isEqualTo: _currentUser?.uid)
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

        return StreamBuilder<QuerySnapshot>(
          stream: doc.reference.collection('status_history').orderBy('timestamp', descending: false).snapshots(),
          builder: (context, historySnapshot) {
            Map<String, DateTime?> historyTimes = {};
            if (historySnapshot.hasData) {
              for (var hDoc in historySnapshot.data!.docs) {
                final hData = hDoc.data() as Map<String, dynamic>;
                historyTimes[hData['status']] = (hData['timestamp'] as Timestamp?)?.toDate();
              }
            }

            return ListView(
              padding: const EdgeInsets.all(25),
              children: [
                _buildPackageSummary(booking),
                const SizedBox(height: 30),
                const Text("JOURNEY LOG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
                const SizedBox(height: 20),
                _buildTimelineStep("Ordered", "Package request received", booking.createdAt, true),
                _buildTimelineStep("Accepted", "Driver ${booking.carrierName} assigned", historyTimes['accepted'], booking.statusProgress >= 1),
                _buildTimelineStep("In Transit", "Carrier is moving to destination", historyTimes['out_for_delivery'], booking.statusProgress >= 2),
                _buildTimelineStep("Delivered", "Package reached destination", historyTimes['delivered'], booking.statusProgress >= 3),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildTimelineStep(String title, String desc, DateTime? time, bool isDone) {
    Color color = isDone ? Colors.green : Colors.grey[300]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isDone ? Colors.green : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isDone 
                ? const Icon(Icons.check, color: Colors.white, size: 14) 
                : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle))),
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
              if (time != null) 
                Text(DateFormat('MMM dd, hh:mm a').format(time), style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
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
              Icon(Icons.location_on, size: 14, color: Theme.of(context).primaryColor),
              const SizedBox(width: 5),
              Expanded(child: Text("Destination: ${booking.deliveryAddress}", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
          const Text("Click the search bar to see your active bookings.", style: TextStyle(color: Colors.grey, fontSize: 11)),
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
          const Text("Ensure the ID is correct and linked to your account.", 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          TextButton(onPressed: () => setState(() => _searchId = null), child: const Text("Try Again"))
        ],
      ),
    );
  }
}
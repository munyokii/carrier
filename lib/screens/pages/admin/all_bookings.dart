import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/admin/assign_driver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class AllBookings extends StatefulWidget {
  const AllBookings({super.key});

  @override
  State<AllBookings> createState() => _AllBookingsState();
}

class _AllBookingsState extends State<AllBookings> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _contactRecipient(String? phone, {required bool isWhatsapp}) async {
    if (phone == null || phone.isEmpty) return;

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    final Uri url = isWhatsapp
        ? Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent("Hello, your Swiftline package is ready for pickup.")}")
        : Uri.parse("tel:$phone");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (isWhatsapp) {
          final webUrl = Uri.parse("https://wa.me/$cleanPhone");
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("Could not launch $url: $e");
    }
  }

  Future<void> _markAsPicked(BookingModel booking) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('bookings').doc(booking.id);
      await docRef.update({'status': 'picked'});
      await docRef.collection('status_history').add({
        'message': 'Package picked up/checked out by recipient',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'picked',
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Checkout Complete: Package marked as Picked")),
        );
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> _printQrLabel(BookingModel booking) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text("SWIFTLINE CARRIER", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.BarcodeWidget(
              data: booking.trackingNumber, 
              barcode: pw.Barcode.qrCode(), 
              width: 100, 
              height: 100
            ),
            pw.SizedBox(height: 10),
            pw.Text("TRACKING ID: ${booking.trackingNumber}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text("Item: ${booking.itemDescription}", style: const pw.TextStyle(fontSize: 9)),
            pw.Text("Dest: ${booking.deliveryAddress}", style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Label_${booking.trackingNumber}');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Manage Bookings", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(115), 
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toUpperCase());
                    },
                    decoration: InputDecoration(
                      hintText: "Search Tracking ID...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F3F4),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                TabBar(
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: "Pending"),
                    Tab(text: "Accepted"),
                    Tab(text: "To Be Picked"),
                    Tab(text: "Completed"),
                    Tab(text: "Cancelled"),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildBookingList(statuses: ['pending']),
            _buildBookingList(statuses: ['accepted', 'out_for_delivery']), 
            _buildBookingList(statuses: ['delivered']),
            _buildBookingList(statuses: ['picked']),
            _buildBookingList(statuses: ['cancelled']),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList({required List<String> statuses}) {
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', whereIn: statuses);

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('trackingNumber', isGreaterThanOrEqualTo: _searchQuery)
          .where('trackingNumber', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(_searchQuery.isEmpty 
                  ? "No bookings in this section." 
                  : "No match for '$_searchQuery'"),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final booking = BookingModel.fromFirestore(
              snapshot.data!.docs[index].data() as Map<String, dynamic>, 
              snapshot.data!.docs[index].id
            );
            return _buildBookingCard(context, booking);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingModel booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.15))
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showBookingDetails(context, booking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(booking.stationName.toUpperCase(), 
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 10, letterSpacing: 0.5)),
                  _buildStatusBadge(booking),
                ],
              ),
              const SizedBox(height: 10),
              Text(booking.itemDescription, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("ID: ${booking.trackingNumber}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const Divider(height: 25, color: Color(0xFFEEEEEE)),
              
              if (booking.status == 'pending')
                _buildWideButton("Assign Driver", () => Navigator.push(context, MaterialPageRoute(builder: (c) => AssignDriver(booking: booking))))
              
              else if (booking.status == 'delivered')
                Row(
                  children: [
                    _buildContactIcon(Icons.phone, Colors.blue, () => _contactRecipient(booking.recipientPhone, isWhatsapp: false)),
                    const SizedBox(width: 8),
                    _buildContactIcon(Icons.message, Colors.green, () => _contactRecipient(booking.recipientPhone, isWhatsapp: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildWideButton("Confirm Pickup", () => _showBookingDetails(context, booking), color: Colors.orange[800])),
                  ],
                )
              
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("View Details", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              QrImageView(data: booking.trackingNumber, size: 160, backgroundColor: Colors.white),
              const SizedBox(height: 10),
              Text(booking.trackingNumber, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
              const Text("SCAN TO TRACK", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
              const Divider(height: 40, color: Color(0xFFF5F5F5)),
              _buildDetailRow("Item", booking.itemDescription),
              _buildDetailRow("Weight", "${booking.weight} kg"),
              _buildDetailRow("Carrier", booking.carrierName),
              const SizedBox(height: 20),
              _buildStatusHistory(booking.id),
              const Divider(height: 40, color: Color(0xFFF5F5F5)),
              _buildDetailRow("Recipient Phone", booking.recipientPhone),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: IconButton.filledTonal(
                      onPressed: () => _contactRecipient(booking.recipientPhone, isWhatsapp: false),
                      icon: const Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IconButton.filledTonal(
                      onPressed: () => _contactRecipient(booking.recipientPhone, isWhatsapp: true),
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (booking.status == 'delivered') ...[
                const Text("RECIPIENT IS AT THE STATION?", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _markAsPicked(booking),
                  child: const Text("COMPLETE CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => _printQrLabel(booking),
                icon: const Icon(Icons.print),
                label: const Text("PRINT LABEL"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideButton(String text, VoidCallback onPressed, {Color? color}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildContactIcon(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: IconButton(onPressed: onTap, icon: Icon(icon, color: color, size: 20)),
    );
  }


  Widget _buildStatusHistory(String bookingId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').doc(bookingId).collection('status_history').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final logs = snapshot.data!.docs;
        return Container(
          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ACTIVITY LOG", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              ...logs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final time = (data['timestamp'] as Timestamp?)?.toDate();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  title: Text(data['message'] ?? 'Status updated', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(time != null ? DateFormat('MMM dd, hh:mm a').format(time) : '...', style: const TextStyle(fontSize: 10)),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(BookingModel booking) {
    Color color;
    switch (booking.status) {
      case 'accepted': color = Colors.green; break;
      case 'picked': color = Colors.blueAccent; break;
      case 'delivered': color = Colors.blue; break;
      case 'cancelled': color = Colors.red; break;
      case 'out_for_delivery': color = Colors.purple; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(booking.status.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)), 
          Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ]
      ),
    );
  }
}
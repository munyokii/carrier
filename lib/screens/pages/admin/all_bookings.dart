import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/models/booking_model.dart';
import 'package:carrier/screens/pages/admin/assign_driver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AllBookings extends StatelessWidget {
  const AllBookings({super.key});

  // PDF Printing Logic
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
            pw.BarcodeWidget(data: booking.id, barcode: pw.Barcode.qrCode(), width: 100, height: 100),
            pw.SizedBox(height: 10),
            pw.Text("ID: ${booking.id.toUpperCase()}", style: const pw.TextStyle(fontSize: 8)),
            pw.Divider(),
            pw.Text("Item: ${booking.itemDescription}", style: const pw.TextStyle(fontSize: 9)),
            pw.Text("Dest: ${booking.deliveryAddress}", style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Label_${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Manage Bookings", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            labelColor: Colors.blue,
            indicatorColor: Colors.blue,
            tabs: [Tab(text: "Pending"), Tab(text: "Accepted"), Tab(text: "Cancelled")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBookingList('pending'),
            _buildBookingList('accepted'),
            _buildBookingList('cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Text("No $status bookings."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final booking = BookingModel.fromFirestore(snapshot.data!.docs[index].data() as Map<String, dynamic>, snapshot.data!.docs[index].id);
            return _buildBookingCard(context, booking);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingModel booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showBookingDetails(context, booking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(booking.stationName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 11)),
                  _buildStatusBadge(booking),
                ],
              ),
              const SizedBox(height: 10),
              Text(booking.itemDescription, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 25),
              if (booking.status == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AssignDriver(booking: booking))),
                    child: const Text("Assign Driver"),
                  ),
                )
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("View Details", style: TextStyle(color: Colors.grey, fontSize: 12)), Icon(Icons.chevron_right, size: 16)],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              QrImageView(data: booking.id, size: 180),
              const Text("SCAN TO TRACK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10)),
              const Divider(height: 40),
              _buildDetailRow("Item", booking.itemDescription),
              _buildDetailRow("Weight", "${booking.weight} kg"),
              _buildDetailRow("Carrier", booking.carrierName),
              const SizedBox(height: 30),
              _buildStatusHistory(booking.id),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
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

  Widget _buildStatusHistory(String bookingId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').doc(bookingId).collection('status_history').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final logs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ACTIVITY LOG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            ...logs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final time = (data['timestamp'] as Timestamp?)?.toDate();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                title: Text(data['message'] ?? 'Status updated', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(time != null ? DateFormat('MMM dd, hh:mm a').format(time) : '...', style: const TextStyle(fontSize: 11)),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(BookingModel booking) {
    Color color = booking.status == 'accepted' ? Colors.green : (booking.status == 'cancelled' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(booking.status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }
}
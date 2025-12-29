import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminReports extends StatefulWidget {
  const AdminReports({super.key});

  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports> {
  bool _isGenerating = false;
  
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedStation = "All Stations"; 

  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot> docs) {
    double totalRevenue = 0;
    int completed = 0, cancelled = 0, pending = 0;
    Map<String, int> stationVolume = {};
    Map<String, int> driverPerformance = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'pending';
      final price = (data['price'] ?? 0).toDouble();
      final station = data['stationName'] ?? 'Unknown Hub';
      final driver = data['carrierName'] ?? 'Unassigned';

      if (status == 'delivered') {
        totalRevenue += price;
        completed++;
        if (driver != 'Searching...' && driver != 'Unassigned') {
          driverPerformance[driver] = (driverPerformance[driver] ?? 0) + 1;
        }
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }

      stationVolume[station] = (stationVolume[station] ?? 0) + 1;
    }

    var sortedDrivers = driverPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'revenue': totalRevenue,
      'completed': completed,
      'cancelled': cancelled,
      'pending': pending,
      'total': docs.length,
      'stations': stationVolume,
      'topDrivers': sortedDrivers.take(5).toList(),
    };
  }


  Future<void> _downloadPdfReport(Map<String, dynamic> stats) async {
    setState(() => _isGenerating = true);
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("SWIFTLINE CARRIER - SYSTEM PERFORMANCE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(dateFormat.format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Filter: $_selectedStation", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Text("Reporting Period: ${dateFormat.format(_selectedRange.start)} to ${dateFormat.format(_selectedRange.end)}", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 25),
          
          pw.Text("Operational Summary", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          _pdfRow("Total System Bookings", "${stats['total']}"),
          _pdfRow("Total Generated Revenue", "KES ${stats['revenue'].toStringAsFixed(2)}"),
          _pdfRow("Avg. Completion Rate", "${((stats['completed'] / (stats['total'] > 0 ? stats['total'] : 1)) * 100).toStringAsFixed(1)}%"),
          
          pw.SizedBox(height: 30),
          pw.Text("Top Performing Carriers", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          ... (stats['topDrivers'] as List<MapEntry<String, int>>).map((e) => _pdfRow(e.key, "${e.value} Deliveries")),

          if (_selectedStation == "All Stations") ...[
            pw.SizedBox(height: 30),
            pw.Text("Volume per Hub", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ... (stats['stations'] as Map<String, int>).entries.map((e) => _pdfRow(e.key, "${e.value} packages")),
          ],
          
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 50),
            child: pw.Center(child: pw.Text("--- Confidential Administrative Report ---", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
          )
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Swiftline_Admin_Report');
    setState(() => _isGenerating = false);
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("System Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _selectDateRange, icon: const Icon(Icons.calendar_month))],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildFilteredQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text("Database Error. Ensure indices are created."));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                final stats = _calculateStats(snapshot.data!.docs);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(stats),
                      const SizedBox(height: 25),
                      const Text("Top Carriers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDriverPerformanceList(stats['topDrivers']),
                      if (_selectedStation == "All Stations") ...[
                        const SizedBox(height: 25),
                        const Text("Hub Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildStationList(stats['stations']),
                      ],
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _downloadPdfReport(stats),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: _isGenerating 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Icon(Icons.picture_as_pdf),
                        label: const Text("DOWNLOAD PDF SUMMARY"),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('stations').snapshots(),
            builder: (context, snapshot) {
              List<String> stationNames = ["All Stations"];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  stationNames.add(doc['stationName']);
                }
              }

              return DropdownButtonFormField<String>(
                value: _selectedStation,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  labelText: "Filter by Station",
                  prefixIcon: const Icon(Icons.hub_outlined),
                ),
                items: stationNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (val) => setState(() => _selectedStation = val!),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Period: ${DateFormat('MMM dd').format(_selectedRange.start)} - ${DateFormat('MMM dd').format(_selectedRange.end)}",
                style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13),
              ),
              TextButton.icon(
                onPressed: _selectDateRange, 
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: const Text("Change Date"),
              ),
            ],
          )
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildFilteredQuery() {
    Query query = FirebaseFirestore.instance.collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedRange.start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_selectedRange.end.add(const Duration(days: 1))));

    if (_selectedStation != "All Stations") {
      query = query.where('stationName', isEqualTo: _selectedStation);
    }

    return query.snapshots();
  }

  Widget _buildSummaryCard(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Revenue for ${_selectedStation == 'All Stations' ? 'Entire System' : _selectedStation}", 
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text("KES ${stats['revenue'].toStringAsFixed(2)}", 
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Orders", "${stats['total']}"),
              _miniStat("Delivered", "${stats['completed']}"),
              _miniStat("Cancelled", "${stats['cancelled']}"),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniStat(String l, String v) => Column(children: [Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10))]);

  Widget _buildDriverPerformanceList(List<MapEntry<String, int>> drivers) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: drivers.isEmpty 
          ? [const ListTile(title: Text("No carrier data for this period", style: TextStyle(fontSize: 12, color: Colors.grey)))]
          : drivers.map((e) => ListTile(
            leading: CircleAvatar(backgroundColor: Colors.amber.withOpacity(0.1), child: const Icon(Icons.stars, color: Colors.amber, size: 20)),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            trailing: Text("${e.value} jobs", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          )).toList(),
      ),
    );
  }

  Widget _buildStationList(Map<String, int> data) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: data.entries.map((e) => ListTile(
          title: Text(e.key, style: const TextStyle(fontSize: 14)),
          trailing: Text("${e.value} pkgs", style: const TextStyle(fontWeight: FontWeight.w600)),
        )).toList(),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now(), 
      initialDateRange: _selectedRange
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }

  Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.all(60), child: Column(
    children: [
      Icon(Icons.query_stats, size: 50, color: Colors.grey),
      SizedBox(height: 10),
      Text("No records found for this criteria.", style: TextStyle(color: Colors.grey)),
    ],
  )));
}
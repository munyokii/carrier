import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DriverWallet extends StatelessWidget {
  const DriverWallet({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("My Wallet")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('carrierId', isEqualTo: uid)
            .where('status', isEqualTo: 'delivered')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          double balance = 0;
          for (var doc in snapshot.data!.docs) {
            balance += (doc['price'] ?? 0.0).toDouble();
          }

          return Column(
            children: [
              _buildBalanceHeader(balance, theme),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Recent Transactions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.add_chart)),
                      title: Text("Delivery #${data['trackingNumber']}"),
                      subtitle: Text(data['itemDescription']),
                      trailing: Text("+ KES ${data['price']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceHeader(double balance, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Available Balance", style: TextStyle(color: Colors.white70)),
          Text("KES ${balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {}, // Implement M-Pesa withdrawal logic
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme.primaryColor),
            child: const Text("WITHDRAW TO M-PESA"),
          )
        ],
      ),
    );
  }
}
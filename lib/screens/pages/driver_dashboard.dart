import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text("Welcome, Driver!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Your delivery tasks will appear here once verified.", textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
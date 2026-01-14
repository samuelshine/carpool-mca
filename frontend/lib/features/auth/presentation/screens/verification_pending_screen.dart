import 'package:flutter/material.dart';
import 'package:college_carpool/core/theme/modern_widgets.dart';

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_outlined, size: 80, color: Colors.orange),
            ),
            const SizedBox(height: 32),
            const Text(
              "Identity Verification Required",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "To keep our community safe, you must verify your Christ University ID card before offering or joining rides.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ModernButton(
              text: "Upload ID Card", 
              onPressed: () {
                // TODO: OPEN CAMERA / ML FLOW
              }
            ),
            const SizedBox(height: 16),
            TextButton(child: const Text("Logout"), onPressed: (){})
          ],
        ),
      ),
    );
  }
}

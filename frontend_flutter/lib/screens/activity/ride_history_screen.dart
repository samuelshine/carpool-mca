import 'package:flutter/material.dart';

import '../rides/activity_history_screen.dart';

/// Backward-compatible wrapper for the app's canonical backend-backed history.
///
/// Some older navigation paths still reference `RideHistoryScreen`, so this
/// delegates to `ActivityHistoryScreen` instead of maintaining a separate mock
/// implementation.
class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActivityHistoryScreen();
  }
}

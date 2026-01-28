import 'package:flutter/material.dart';

class StatusPanel extends StatelessWidget {
  final String? targetMac;

  const StatusPanel({super.key, this.targetMac});

  @override
  Widget build(BuildContext context) {
    bool isLocked = targetMac != null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isLocked ? Colors.green[100] : Colors.orange[100],
      width: double.infinity,
      child: Column(
        children: [
          Text(
            isLocked ? "TARGET LOCKED 🔒" : "NO BEACON SELECTED",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (isLocked)
            Text(targetMac!, style: const TextStyle(fontSize: 20, fontFamily: 'monospace')),
          if (!isLocked)
            const Text("Tap a beacon below to set as Factory Beacon"),
        ],
      ),
    );
  }
}
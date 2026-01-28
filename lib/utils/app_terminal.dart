import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

class AppTerminal extends StatelessWidget {
  const AppTerminal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "DEBUG TERMINAL",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildLegend("UI", Colors.lightBlueAccent),
                    SizedBox(width: 8),
                    _buildLegend("Native", Colors.orangeAccent),
                    SizedBox(width: 8),
                    _buildLegend("Main", Colors.purpleAccent),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => AppLogger().clear(),
                      child: Icon(Icons.delete_sweep, color: Colors.grey, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Log content
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: AppLogger().logsNotifier,
              builder: (context, logs, child) {
                if (logs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      "Waiting for logs...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: _getLogColor(log),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Color _getLogColor(String log) {
    // Source-based coloring
    if (log.contains("[Native]")) return Colors.orangeAccent;
    if (log.contains("[UI]")) return Colors.lightBlueAccent;
    if (log.contains("[Main]")) return Colors.purpleAccent;
    if (log.contains("[BG]")) return Colors.amber;
    
    // Status-based coloring
    if (log.contains("❌") || log.contains("Error") || log.contains("error")) {
      return Colors.redAccent;
    }
    if (log.contains("✅") || log.contains("VALID") || log.contains("success")) {
      return Colors.greenAccent;
    }
    if (log.contains("⚠️") || log.contains("Warning") || log.contains("warning")) {
      return Colors.yellow;
    }
    if (log.contains("🎯") || log.contains("DETECTION")) {
      return Colors.cyanAccent;
    }
    if (log.contains("🟢")) return Colors.green;
    if (log.contains("🔴")) return Colors.red;
    
    return Colors.white;
  }
}

import 'package:flutter/material.dart';
import '../utils/beacon_utils.dart';

class BeaconCard extends StatelessWidget {
  final Map<String, dynamic> beacon;

  const BeaconCard({super.key, required this.beacon});

  @override
  Widget build(BuildContext context) {
    final name = beacon['name']?.toString() ?? 'No name';
    final id = beacon['id']?.toString() ?? 'N/A';
    final rssi = beacon['rssi'] as int? ?? -100;

    final bool isLost = beacon['isLost'] == true;

    double distance = BeaconUtils.calculateDistance(rssi);

    String distanceText = isLost ? "--" : BeaconUtils.distanceToString(distance);
    String signalText = isLost ? "NO SIGNAL" : BeaconUtils.getSignalStrength(rssi).replaceAll('童 ', '');

    Color signalColor;
    if (isLost) {
      signalColor = Colors.grey;
    } else {
      signalColor = BeaconUtils.getSignalColor(rssi);
    }

    IconData beaconIcon;
    Color beaconColor;

    if (isLost) {
      beaconIcon = Icons.signal_wifi_bad;
      beaconColor = Colors.grey;
    } else {
      beaconIcon = Icons.verified_user;
      beaconColor = Colors.teal;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: isLost ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: beaconColor.withOpacity(0.5), width: 1.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: beaconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(beaconIcon, color: beaconColor, size: 24),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isLost ? Colors.grey : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),

            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: signalColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: signalColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLost)
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                  else
                    Icon(Icons.bar_chart, size: 12, color: signalColor),

                  const SizedBox(width: 4),
                  Text(
                    isLost ? "Searching for signal..." : signalText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: signalColor
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('MAC: ${id.toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),

            const SizedBox(height: 8),

            if (!isLost)
              Row(
                children: [
                  _buildMiniTag(Icons.radar, '$rssi dBm', Colors.grey.shade700),
                  const SizedBox(width: 12),
                  _buildMiniTag(Icons.straighten, distanceText, Colors.blueGrey),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Target is currently out of range or signal is too weak.",
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontStyle: FontStyle.italic)),
              )
          ],
        ),
        children: [_buildBeaconDetails(beacon, isLost)],
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)
        ),
      ],
    );
  }

  Widget _buildBeaconDetails(Map<String, dynamic> beacon, bool isLost) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailSection('Basic Information', [
            _buildDetailRow('Name', beacon['name']?.toString() ?? 'No name'),
            _buildDetailRow('Status', isLost ? '❌ Signal Lost' : '✅ Active & In Range'),
            _buildDetailRow('MAC Address', beacon['id']?.toString() ?? 'N/A'),
            _buildDetailRow('RSSI', isLost ? 'N/A' : '${beacon['rssi']} dBm'),
          ]),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade800)),
        const Divider(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';

class StatusBar extends StatelessWidget {
  final List<Miner> miners;
  final int selectedCount;

  const StatusBar({
    super.key,
    required this.miners,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    // Count miners by status
    int total = miners.length;
    int active = miners.where((m) => m.status == MinerStatus.active).length;
    int warning = miners.where((m) => m.status == MinerStatus.warning).length;
    int offline = miners.where((m) => m.status == MinerStatus.dead).length;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStatusItem('Total', total, Colors.grey),
          const SizedBox(width: 16),
          _buildStatusItem('Active', active, Colors.green),
          const SizedBox(width: 16),
          _buildStatusItem('Warning', warning, Colors.orange),
          const SizedBox(width: 16),
          _buildStatusItem('Offline', offline, Colors.red),
          const SizedBox(width: 16),
          _buildStatusItem('Selected', selectedCount, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
      ],
    );
  }
}

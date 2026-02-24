import 'package:flutter/material.dart';
import 'package:frontend/src/controllers/action_controller.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/theme/app_theme.dart';

class ActionBar extends StatelessWidget {
  final List<String> selectedIps;
  final List<Miner> allMiners;
  final bool isScanning;
  final bool isMonitoring;
  final ActionController actionController;
  final Set<String> blinkingIps;
  final VoidCallback? onConfigSelected;
  final VoidCallback? onConfigAll;

  const ActionBar({
    super.key,
    required this.selectedIps,
    required this.allMiners,
    required this.isScanning,
    required this.isMonitoring,
    required this.actionController,
    required this.blinkingIps,
    this.onConfigSelected,
    this.onConfigAll,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we are in "blink mode" for the selected IPs
    // If ANY selected IP is blinking, we show "Stop Locate".
    // Or if blinkingIps is not empty?
    // Original logic: `_isBlinking` state. 
    // New logic: Check if we are actively locating.
    // If we have blinking IPs, we probably want to stop them?
    // Determine if we are in "blink mode" for the selected IPs
    // If ANY selected IP is blinking, we show "Stop Locate".
    // We don't need isBlinking state here anymore since button is removed
    // final isBlinking = selectedIps.any((ip) => blinkingIps.contains(ip));

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: context.border, width: 1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Scan Network button
          ElevatedButton.icon(
            onPressed: isScanning ? null : actionController.triggerScan,
            icon: isScanning
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.refresh, size: 16),
            label: Text(isScanning ? 'Scanning...' : 'Scan Network'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Monitor toggle
          ElevatedButton.icon(
            onPressed: actionController.toggleMonitor,
            icon: Icon(Icons.monitor_heart, size: 16),
            label: Text(isMonitoring ? 'Stop Monitor' : 'Monitor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMonitoring ? context.success : null,
              foregroundColor: isMonitoring ? Colors.white : null,
            ),
          ),
          
          // Vertical divider
          Container(
            width: 1,
            height: 24,
            color: context.border,
          ),
          
          // Config All
          OutlinedButton.icon(
            onPressed: onConfigAll,
            icon: Icon(Icons.build, size: 16),
            label: Text('Config All'),
          ),
          
          // Config Selected
          OutlinedButton.icon(
            onPressed: selectedIps.isEmpty ? null : onConfigSelected,
            icon: Icon(Icons.build, size: 16),
            label: Text(
              selectedIps.isEmpty
                  ? 'Config Selected'
                  : 'Config Selected (${selectedIps.length})',
              style: selectedIps.isNotEmpty
                  ? TextStyle(fontFamily: 'monospace')
                  : null,
            ),
          ),
          
          // Vertical divider
          Container(
            width: 1,
            height: 24,
            color: context.border,
          ),
          
          // Reboot All
          OutlinedButton.icon(
            onPressed: allMiners.isEmpty ? null : () => actionController.rebootAll(context),
            icon: Icon(Icons.restart_alt, size: 16),
            label: Text('Reboot All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.error,
            ),
          ),
          
          // Reboot Selected
          OutlinedButton.icon(
            onPressed: selectedIps.isEmpty ? null : () => actionController.rebootSelected(context),
            icon: Icon(Icons.restart_alt, size: 16),
            label: Text(
              selectedIps.isEmpty
                  ? 'Reboot Selected'
                  : 'Reboot Selected (${selectedIps.length})',
              style: selectedIps.isNotEmpty
                  ? TextStyle(fontFamily: 'monospace')
                  : null,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.error,
            ),
          ),
          
        ],
      ),
    );
  }
}

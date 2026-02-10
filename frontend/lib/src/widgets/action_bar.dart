import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/api/monitor.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/widgets/firmware_dialog.dart';

class ActionBar extends StatelessWidget {
  final List<String> selectedIps;
  final List<Miner> allMiners;
  final bool isScanning;
  final bool isMonitoring;
  final Function(bool) onMonitorToggle;
  final Function(String) onShowToast;
  final Future<void> Function() onTriggerScan;

  const ActionBar({
    super.key,
    required this.selectedIps,
    required this.allMiners,
    required this.isScanning,
    required this.isMonitoring,
    required this.onMonitorToggle,
    required this.onShowToast,
    required this.onTriggerScan,
  });

  Future<void> _handleRebootAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Reboot All'),
        content: Text('Are you sure you want to reboot all ${allMiners.length} miners?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Reboot All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ips = allMiners.map((m) => m.ip).toList();
      await _executeReboot(ips);
    }
  }

  Future<void> _handleRebootSelected(BuildContext context) async {
    if (selectedIps.isEmpty) {
      onShowToast('No miners selected');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Reboot Selected'),
        content: Text('Are you sure you want to reboot ${selectedIps.length} selected miners?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Reboot'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeReboot(selectedIps);
    }
  }

  Future<void> _executeReboot(List<String> ips) async {
    try {
      final results = await executeBatchCommand(
        targetIps: ips,
        command: MinerCommand.reboot,
      );
      
      final successCount = results.where((r) => r.success).length;
      onShowToast('Reboot initiated: $successCount/${ips.length} successful');
    } catch (e) {
      onShowToast('Reboot failed: $e');
    }
  }

  Future<void> _handleMonitorToggle() async {
    try {
      if (isMonitoring) {
        await stopMonitoring();
        onMonitorToggle(false);
        onShowToast('Monitoring stopped');
      } else {
        final ips = allMiners.map((m) => m.ip).toList();
        if (ips.isEmpty) {
          onShowToast('No miners to monitor');
          return;
        }
        await startMonitoring(ips: ips);
        onMonitorToggle(true);
        onShowToast('Monitoring started for ${ips.length} miners');
      }
    } catch (e) {
      onShowToast('Monitor toggle failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: isScanning ? null : onTriggerScan,
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
            onPressed: _handleMonitorToggle,
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
            onPressed: () => onShowToast('Config All not implemented yet'),
            icon: Icon(Icons.build, size: 16),
            label: Text('Config All'),
          ),
          
          // Config Selected
          OutlinedButton.icon(
            onPressed: selectedIps.isEmpty
                ? null
                : () => onShowToast('Config Selected not implemented yet'),
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
            onPressed: allMiners.isEmpty ? null : () => _handleRebootAll(context),
            icon: Icon(Icons.restart_alt, size: 16),
            label: Text('Reboot All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.error,
            ),
          ),
          
          // Reboot Selected
          OutlinedButton.icon(
            onPressed: selectedIps.isEmpty ? null : () => _handleRebootSelected(context),
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
          
          // Vertical divider
          Container(
            width: 1,
            height: 24,
            color: context.border,
          ),
          
          // Firmware Upgrade
          OutlinedButton.icon(
            onPressed: selectedIps.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (context) => FirmwareDialog(
                        targetIps: selectedIps,
                      ),
                    );
                  },
            icon: Icon(Icons.upload_file, size: 16),
            label: Text(
              selectedIps.isEmpty
                  ? 'Firmware Upgrade'
                  : 'Firmware Upgrade (${selectedIps.length})',
              style: selectedIps.isNotEmpty
                  ? TextStyle(fontFamily: 'monospace')
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

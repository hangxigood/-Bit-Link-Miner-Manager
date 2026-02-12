import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/api/monitor.dart';
import 'package:frontend/src/theme/app_theme.dart';

class ActionBar extends StatefulWidget {
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

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  bool _isBlinking = false;
  Set<String> _blinkingIps = {}; // Track which IPs are currently blinking

  @override
  void didUpdateWidget(ActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When selection changes, stop blinking on previously selected miners
    if (oldWidget.selectedIps.length != widget.selectedIps.length ||
        !_listsEqual(oldWidget.selectedIps, widget.selectedIps)) {
      // Find IPs that were blinking but are no longer selected
      final deselectedBlinkingIps = _blinkingIps
          .where((ip) => !widget.selectedIps.contains(ip))
          .toList();
      
      if (deselectedBlinkingIps.isNotEmpty) {
        // Stop blinking on deselected miners
        _stopBlinkingOnIps(deselectedBlinkingIps);
      }
      
      // Update UI state
      setState(() {
        _isBlinking = false;
        _blinkingIps.removeWhere((ip) => !widget.selectedIps.contains(ip));
      });
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Helper method to stop blinking on specific IPs without showing toast
  Future<void> _stopBlinkingOnIps(List<String> ips) async {
    try {
      await executeBatchCommand(
        targetIps: ips,
        command: MinerCommand.stopBlink,
      );
    } catch (e) {
      // Silently fail - this is a background cleanup operation
    }
  }

  Future<void> _handleRebootAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Reboot All'),
        content: Text('Are you sure you want to reboot all ${widget.allMiners.length} miners?'),
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
      final ips = widget.allMiners.map((m) => m.ip).toList();
      await _executeReboot(ips);
    }
  }

  Future<void> _handleRebootSelected(BuildContext context) async {
    if (widget.selectedIps.isEmpty) {
      widget.onShowToast('No miners selected');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Reboot Selected'),
        content: Text('Are you sure you want to reboot ${widget.selectedIps.length} selected miners?'),
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
      await _executeReboot(widget.selectedIps);
    }
  }

  Future<void> _executeReboot(List<String> ips) async {
    try {
      final results = await executeBatchCommand(
        targetIps: ips,
        command: MinerCommand.reboot,
      );
      
      final successCount = results.where((r) => r.success).length;
      widget.onShowToast('Reboot initiated: $successCount/${ips.length} successful');
    } catch (e) {
      widget.onShowToast('Reboot failed: $e');
    }
  }

  Future<void> _handleMonitorToggle() async {
    try {
      if (widget.isMonitoring) {
        await stopMonitoring();
        widget.onMonitorToggle(false);
        widget.onShowToast('Monitoring stopped');
      } else {
        final ips = widget.allMiners.map((m) => m.ip).toList();
        if (ips.isEmpty) {
          widget.onShowToast('No miners to monitor');
          return;
        }
        await startMonitoring(ips: ips);
        widget.onMonitorToggle(true);
        widget.onShowToast('Monitoring started for ${ips.length} miners');
      }
    } catch (e) {
      widget.onShowToast('Monitor toggle failed: $e');
    }
  }

  Future<void> _handleLocateToggle() async {
    if (widget.selectedIps.isEmpty) {
      widget.onShowToast('No miners selected');
      return;
    }

    try {
      if (_isBlinking) {
        // Stop blinking
        final results = await executeBatchCommand(
          targetIps: widget.selectedIps,
          command: MinerCommand.stopBlink,
        );
        final successCount = results.where((r) => r.success).length;
        setState(() {
          _isBlinking = false;
          // Remove successfully stopped IPs from tracking
          for (var result in results) {
            if (result.success) {
              _blinkingIps.remove(result.ip);
            }
          }
        });
        widget.onShowToast('Stopped blinking: $successCount/${widget.selectedIps.length} successful');
      } else {
        // Start blinking
        final results = await executeBatchCommand(
          targetIps: widget.selectedIps,
          command: MinerCommand.blinkLed,
        );
        final successCount = results.where((r) => r.success).length;
        setState(() {
          _isBlinking = true;
          // Track successfully blinking IPs
          for (var result in results) {
            if (result.success) {
              _blinkingIps.add(result.ip);
            }
          }
        });
        widget.onShowToast('Started blinking: $successCount/${widget.selectedIps.length} successful');
      }
    } catch (e) {
      widget.onShowToast('Locate failed: $e');
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
            onPressed: widget.isScanning ? null : widget.onTriggerScan,
            icon: widget.isScanning
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.refresh, size: 16),
            label: Text(widget.isScanning ? 'Scanning...' : 'Scan Network'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Monitor toggle
          ElevatedButton.icon(
            onPressed: _handleMonitorToggle,
            icon: Icon(Icons.monitor_heart, size: 16),
            label: Text(widget.isMonitoring ? 'Stop Monitor' : 'Monitor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isMonitoring ? context.success : null,
              foregroundColor: widget.isMonitoring ? Colors.white : null,
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
            onPressed: () => widget.onShowToast('Config All not implemented yet'),
            icon: Icon(Icons.build, size: 16),
            label: Text('Config All'),
          ),
          
          // Config Selected
          OutlinedButton.icon(
            onPressed: widget.selectedIps.isEmpty
                ? null
                : () => widget.onShowToast('Config Selected not implemented yet'),
            icon: Icon(Icons.build, size: 16),
            label: Text(
              widget.selectedIps.isEmpty
                  ? 'Config Selected'
                  : 'Config Selected (${widget.selectedIps.length})',
              style: widget.selectedIps.isNotEmpty
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
            onPressed: widget.allMiners.isEmpty ? null : () => _handleRebootAll(context),
            icon: Icon(Icons.restart_alt, size: 16),
            label: Text('Reboot All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.error,
            ),
          ),
          
          // Reboot Selected
          OutlinedButton.icon(
            onPressed: widget.selectedIps.isEmpty ? null : () => _handleRebootSelected(context),
            icon: Icon(Icons.restart_alt, size: 16),
            label: Text(
              widget.selectedIps.isEmpty
                  ? 'Reboot Selected'
                  : 'Reboot Selected (${widget.selectedIps.length})',
              style: widget.selectedIps.isNotEmpty
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
          
          // Locate (Blink LED) - Toggle button
          OutlinedButton.icon(
            onPressed: widget.selectedIps.isEmpty ? null : _handleLocateToggle,
            icon: Icon(
              _isBlinking ? Icons.location_disabled : Icons.location_searching,
              size: 16,
            ),
            label: Text(
              _isBlinking
                  ? 'Stop Locate'
                  : (widget.selectedIps.isEmpty
                      ? 'Locate'
                      : 'Locate (${widget.selectedIps.length})'),
              style: widget.selectedIps.isNotEmpty && !_isBlinking
                  ? TextStyle(fontFamily: 'monospace')
                  : null,
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: _isBlinking ? Colors.orange.withOpacity(0.1) : null,
              foregroundColor: _isBlinking ? Colors.orange : null,
              side: _isBlinking
                  ? BorderSide(color: Colors.orange, width: 1.5)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

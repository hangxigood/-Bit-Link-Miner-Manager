import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/api/monitor.dart';
import 'package:frontend/src/services/batch_settings_service.dart';
import 'package:frontend/src/theme/app_theme.dart';

class ActionBar extends StatefulWidget {
  final List<String> selectedIps;
  final List<Miner> allMiners;
  final bool isScanning;
  final bool isMonitoring;
  final Function(bool) onMonitorToggle;
  final Function(String) onShowToast;
  final Future<List<Miner>> Function() onTriggerScan;

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
    final ips = widget.allMiners.map((m) => m.ip).toList();
    if (ips.isEmpty) {
      widget.onShowToast('No miners to reboot');
      return;
    }
    await _showRebootConfigDialog(context, ips, 'Reboot All (${ips.length} miners)');
  }

  Future<void> _handleRebootSelected(BuildContext context) async {
    if (widget.selectedIps.isEmpty) {
      widget.onShowToast('No miners selected');
      return;
    }
    await _showRebootConfigDialog(context, widget.selectedIps, 'Reboot Selected (${widget.selectedIps.length} miners)');
  }

  Future<void> _showRebootConfigDialog(BuildContext context, List<String> ips, String title) async {
    // Load last-used values
    final savedBatchSize = await BatchSettingsService.getBatchSize();
    final savedBatchDelay = await BatchSettingsService.getBatchDelay();

    if (!context.mounted) return;

    final batchSizeController = TextEditingController(text: savedBatchSize.toString());
    final batchDelayController = TextEditingController(text: savedBatchDelay.toString());

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure staggered reboot to avoid power surges, or reboot all at once.',
                style: TextStyle(fontSize: 13, color: context.mutedText),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: batchSizeController,
                      decoration: InputDecoration(
                        labelText: 'Batch Size',
                        helperText: 'Miners per batch (1–50)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: batchDelayController,
                      decoration: InputDecoration(
                        labelText: 'Delay (seconds)',
                        helperText: 'Wait between batches (1–60)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ListenableBuilder(
                listenable: Listenable.merge([batchSizeController, batchDelayController]),
                builder: (context, _) {
                  final batchSize = (int.tryParse(batchSizeController.text) ?? savedBatchSize).clamp(1, 50);
                  final totalBatches = (ips.length / batchSize).ceil();
                  final delay = int.tryParse(batchDelayController.text) ?? savedBatchDelay;
                  final totalTime = (totalBatches - 1) * delay;
                  return Text(
                    '$totalBatches batches · ~${totalTime}s total wait',
                    style: TextStyle(fontSize: 11, color: context.mutedText),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'staggered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Staggered Reboot'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'at_once'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Reboot at Once'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final batchSize = (int.tryParse(batchSizeController.text) ?? savedBatchSize).clamp(1, 50);
    final batchDelay = (int.tryParse(batchDelayController.text) ?? savedBatchDelay).clamp(1, 60);

    // Save last-used values
    await BatchSettingsService.setBatchSize(batchSize);
    await BatchSettingsService.setBatchDelay(batchDelay);

    if (result == 'at_once') {
      await _executeRebootImmediate(ips);
    } else {
      await _executeStaggeredReboot(ips, batchSize, batchDelay);
    }
  }

  Future<void> _executeRebootImmediate(List<String> ips) async {
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

  Future<void> _executeStaggeredReboot(List<String> ips, int batchSize, int batchDelay) async {
    // Split IPs into batches
    final List<List<String>> batches = [];
    for (var i = 0; i < ips.length; i += batchSize) {
      batches.add(ips.sublist(i, (i + batchSize).clamp(0, ips.length)));
    }

    bool cancelled = false;
    int completedMiners = 0;
    int successCount = 0;
    int failCount = 0;

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _StaggeredProgressDialog(
        key: _progressKey,
        totalMiners: ips.length,
        totalBatches: batches.length,
        batchDelay: batchDelay,
        onCancel: () {
          cancelled = true;
          Navigator.of(dialogContext).pop();
        },
      ),
    );

    // Execute batches
    for (var i = 0; i < batches.length; i++) {
      if (cancelled) break;

      // Update progress dialog
      _progressKey.currentState?.updateProgress(
        currentBatch: i + 1,
        completedMiners: completedMiners,
        successCount: successCount,
        failCount: failCount,
        isWaiting: false,
      );

      try {
        final results = await executeBatchCommand(
          targetIps: batches[i],
          command: MinerCommand.reboot,
        );
        completedMiners += batches[i].length;
        successCount += results.where((r) => r.success).length;
        failCount += results.where((r) => !r.success).length;
      } catch (e) {
        completedMiners += batches[i].length;
        failCount += batches[i].length;
      }

      // Wait between batches (except after the last one)
      if (i < batches.length - 1 && !cancelled) {
        _progressKey.currentState?.updateProgress(
          currentBatch: i + 1,
          completedMiners: completedMiners,
          successCount: successCount,
          failCount: failCount,
          isWaiting: true,
        );

        // Countdown delay — check cancel flag each second
        for (var s = batchDelay; s > 0 && !cancelled; s--) {
          _progressKey.currentState?.updateCountdown(s);
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }

    // Dismiss progress dialog
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final status = cancelled ? 'Cancelled' : 'Complete';
    widget.onShowToast('Reboot $status: $successCount success, $failCount failed out of ${ips.length}');
  }

  final GlobalKey<_StaggeredProgressDialogState> _progressKey = GlobalKey();

  Future<void> _handleMonitorToggle() async {
    try {
      if (widget.isMonitoring) {
        // Stop monitoring - don't await to avoid UI freeze
        widget.onMonitorToggle(false);
        stopMonitoring().catchError((e) {
          // Silently handle errors
        });
        widget.onShowToast('Monitoring stopped');
      } else {
        var miners = widget.allMiners;
        if (miners.isEmpty) {
          // No miners yet — trigger a scan first, then start monitoring
          widget.onShowToast('Scanning network first...');
          miners = await widget.onTriggerScan();
          
          if (miners.isEmpty) {
            widget.onShowToast('No miners found after scan');
            return;
          }
        }
        await startMonitoring(miners: miners);
        widget.onMonitorToggle(true);
        widget.onShowToast('Monitoring started for ${miners.length} miners');
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

/// Progress dialog shown during staggered batch reboot execution.
class _StaggeredProgressDialog extends StatefulWidget {
  final int totalMiners;
  final int totalBatches;
  final int batchDelay;
  final VoidCallback onCancel;

  const _StaggeredProgressDialog({
    super.key,
    required this.totalMiners,
    required this.totalBatches,
    required this.batchDelay,
    required this.onCancel,
  });

  @override
  State<_StaggeredProgressDialog> createState() => _StaggeredProgressDialogState();
}

class _StaggeredProgressDialogState extends State<_StaggeredProgressDialog> {
  int _currentBatch = 1;
  int _completedMiners = 0;
  int _successCount = 0;
  int _failCount = 0;
  bool _isWaiting = false;
  int _countdown = 0;

  void updateProgress({
    required int currentBatch,
    required int completedMiners,
    required int successCount,
    required int failCount,
    required bool isWaiting,
  }) {
    if (!mounted) return;
    setState(() {
      _currentBatch = currentBatch;
      _completedMiners = completedMiners;
      _successCount = successCount;
      _failCount = failCount;
      _isWaiting = isWaiting;
    });
  }

  void updateCountdown(int seconds) {
    if (!mounted) return;
    setState(() {
      _countdown = seconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalMiners > 0
        ? _completedMiners / widget.totalMiners
        : 0.0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 8),
          Text('Staggered Reboot'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch progress text
            Text(
              _isWaiting
                  ? 'Waiting ${_countdown}s before next batch...'
                  : 'Executing batch $_currentBatch of ${widget.totalBatches}...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            SizedBox(height: 8),

            // Stats row
            Text(
              '$_completedMiners / ${widget.totalMiners} miners processed',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text('$_successCount success', style: TextStyle(fontSize: 12)),
                SizedBox(width: 16),
                if (_failCount > 0) ...[
                  Icon(Icons.error, size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Text('$_failCount failed', style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    );
  }
}

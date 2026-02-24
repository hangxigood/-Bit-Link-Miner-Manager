import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/src/controllers/dashboard_controller.dart';
import 'package:frontend/src/rust/api/commands.dart' as commands;
import 'package:frontend/src/rust/api/commands.dart' show MinerCommand, CommandResult, setMinerPools;
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/core/config.dart';
import 'package:frontend/src/widgets/reboot_progress_dialog.dart';
import 'package:frontend/src/widgets/reboot_config_dialog.dart';

class ActionController {
  final DashboardController _dashboardController;
  final Function(String) _onShowToast;
  final Future<List<Miner>> Function()? _onTriggerScan;
  final Future<List<CommandResult>> Function({
    required List<String> targetIps,
    required MinerCommand command,
    MinerCredentials? credentials,
  }) _executeBatchCommand;

  ActionController({
    required DashboardController dashboardController,
    required Function(String) onShowToast,
    Future<List<Miner>> Function()? onTriggerScan,
    Future<List<CommandResult>> Function({
      required List<String> targetIps,
      required MinerCommand command,
      MinerCredentials? credentials,
    })? executeBatchCommand,
  })  : _dashboardController = dashboardController,
        _onShowToast = onShowToast,
        _onTriggerScan = onTriggerScan,
        _executeBatchCommand = executeBatchCommand ?? commands.executeBatchCommand;
  /// Apply pool config to a single miner. Used internally by DashboardShell
  /// for concurrent pool+power-mode dispatch.
  Future<CommandResult> setPoolsForIp(String ip, List<PoolConfig> pools) =>
      setMinerPools(ip: ip, pools: pools);

  // --- Scanning ---

  Future<void> triggerScan() async {
    if (_onTriggerScan != null) {
      await _onTriggerScan();
    }
  }

  // --- Monitoring ---

  Future<void> toggleMonitor() async {
    try {
      if (_dashboardController.isMonitoring) {
        _dashboardController.toggleMonitoring(false);
        _onShowToast('Monitoring stopped');
      } else {
        var miners = _dashboardController.miners;
        if (miners.isEmpty) {
          // If no miners, try to scan if we can
          if (_onTriggerScan != null) {
             _onShowToast('Scanning network first...');
             miners = await _onTriggerScan();
             if (miners.isEmpty) {
               _onShowToast('No miners found after scan');
               return;
             }
          } else {
             _onShowToast('No miners to monitor. Please scan network first.');
             return;
          }
        }
        _dashboardController.toggleMonitoring(true);
        _onShowToast('Monitoring started for ${miners.length} miners');
      }
    } catch (e) {
      _dashboardController.toggleMonitoring(false);
      _onShowToast('Monitor toggle failed: $e');
    }
  }

  // --- Pool Config ---

  /// Push pool configuration to the selected miners.
  /// Each miner is configured concurrently. The miner will reboot automatically
  /// after accepting the new pool configuration.
  Future<void> configSelected(
    List<String> selectedIps,
    List<PoolConfig> pools,
  ) async {
    if (selectedIps.isEmpty) {
      _onShowToast('No miners selected');
      return;
    }
    if (pools.isEmpty) {
      _onShowToast('No pool configured — fill in Pool 1 URL first');
      return;
    }

    _onShowToast('Pushing pool config to ${selectedIps.length} miner(s)…');

    final results = await Future.wait(
      selectedIps.map((ip) => setMinerPools(ip: ip, pools: pools)),
    );

    final successCount = results.where((r) => r.success).length;
    final failCount = results.length - successCount;

    if (failCount == 0) {
      _onShowToast(
        'Pool config applied to $successCount miner(s). Miners will reboot shortly.',
      );
    } else {
      _onShowToast(
        'Pool config: $successCount ok, $failCount failed. Check miner credentials.',
      );
    }
  }


  Future<void> toggleLocate(List<String> selectedIps) async {
    if (selectedIps.isEmpty) {
      _onShowToast('No miners selected');
      return;
    }

    // Check if any of the selected IPs are currently blinking
    // This fixes the regression where blinking state was global.
    final isBlinking = selectedIps.any((ip) => _dashboardController.blinkingIps.contains(ip));

    try {
      if (isBlinking) {
        final results = await _executeBatchCommand(
          targetIps: selectedIps,
          command: const MinerCommand.stopBlink(),
        );
        
        final successCount = results.where((r) => r.success).length;
        
        for (var result in results) {
          if (result.success) {
            _dashboardController.updateBlinkStatus(result.ip, false);
          }
        }
        
        _onShowToast('Stopped blinking: $successCount/${selectedIps.length} successful');
      } else {
        final results = await _executeBatchCommand(
          targetIps: selectedIps,
          command: const MinerCommand.blinkLed(),
        );
        
        final successCount = results.where((r) => r.success).length;

        for (var result in results) {
          if (result.success) {
             _dashboardController.updateBlinkStatus(result.ip, true);
          }
        }
        _onShowToast('Started blinking: $successCount/${selectedIps.length} successful');
      }
    } catch (e) {
      _onShowToast('Locate failed: $e');
    }
  }

  // --- Reboot ---

  Future<void> rebootAll(BuildContext context) async {
    final ips = _dashboardController.miners.map((m) => m.ip).toList();
    if (ips.isEmpty) {
      _onShowToast('No miners to reboot');
      return;
    }
    await _showRebootConfigDialog(context, ips, 'Reboot All (${ips.length} miners)');
  }

  Future<void> rebootSelected(BuildContext context) async {
    final ips = _dashboardController.selectedMinerIps;
    if (ips.isEmpty) {
      _onShowToast('No miners selected');
      return;
    }
    await _showRebootConfigDialog(context, ips, 'Reboot Selected (${ips.length} miners)');
  }

  Future<void> _showRebootConfigDialog(BuildContext context, List<String> ips, String title) async {
    // Show Config Dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RebootConfigDialog(
        totalMiners: ips.length,
        title: title,
      ),
    );

    if (result == null) return;

    final action = result['action'] as String;
    final batchSize = result['batchSize'] as int;
    final batchDelay = result['batchDelay'] as int;

    if (!context.mounted) return;

    if (action == 'at_once') {
      await _executeRebootImmediate(ips);
    } else {
      await _executeStaggeredReboot(context, ips, batchSize, batchDelay);
    }
  }

  Future<void> _executeRebootImmediate(List<String> ips) async {
    try {
      final results = await _executeBatchCommand(
        targetIps: ips,
        command: const MinerCommand.reboot(),
      );
      final successCount = results.where((r) => r.success).length;
      _onShowToast('Reboot initiated: $successCount/${ips.length} successful');
    } catch (e) {
      _onShowToast('Reboot failed: $e');
    }
  }

  Future<void> _executeStaggeredReboot(
    BuildContext context,
    List<String> ips,
    int batchSize,
    int batchDelay,
  ) async {
    final List<List<String>> batches = [];
    for (var i = 0; i < ips.length; i += batchSize) {
      batches.add(ips.sublist(i, (i + batchSize).clamp(0, ips.length)));
    }

    bool cancelled = false;

    // Show progress dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => RebootProgressDialog(
          totalMiners: ips.length,
          totalBatches: batches.length,
          batchDelay: batchDelay,
          onCancel: () {
            cancelled = true;
            Navigator.of(dialogContext).pop();
          },
          stream: _executeBatches(batches, batchDelay, () => cancelled),
        ),
      );
    }
  }

  Stream<RebootProgressState> _executeBatches(
    List<List<String>> batches,
    int batchDelay,
    bool Function() isCancelled,
  ) async* {
    int completedMiners = 0;
    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < batches.length; i++) {
      if (isCancelled()) break;

      yield RebootProgressState(
        currentBatch: i + 1,
        completedMiners: completedMiners,
        successCount: successCount,
        failCount: failCount,
        isWaiting: false,
        countdown: 0,
      );

      try {
        final results = await _executeBatchCommand(
          targetIps: batches[i],
          command: const MinerCommand.reboot(),
        );
        completedMiners += batches[i].length;
        successCount += results.where((r) => r.success).length;
        failCount += results.where((r) => !r.success).length;
      } catch (e) {
        completedMiners += batches[i].length;
        failCount += batches[i].length; 
      }

      // Wait between batches
      if (i < batches.length - 1 && !isCancelled()) {
        for (var s = batchDelay; s > 0 && !isCancelled(); s--) {
          yield RebootProgressState(
            currentBatch: i + 1,
            completedMiners: completedMiners,
            successCount: successCount,
            failCount: failCount,
            isWaiting: true,
            countdown: s,
          );
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }
    
    // Final state
    if (!isCancelled()) {
      yield RebootProgressState(
          currentBatch: batches.length,
          completedMiners: completedMiners,
          successCount: successCount,
          failCount: failCount,
          isWaiting: false,
          countdown: 0,
          isComplete: true,
      );
      _onShowToast('Reboot Complete: $successCount success, $failCount failed');
    } else {
       _onShowToast('Reboot Cancelled: $successCount success, $failCount failed');
    }
  }
}

class RebootProgressState {
  final int currentBatch;
  final int completedMiners;
  final int successCount;
  final int failCount;
  final bool isWaiting;
  final int countdown;
  final bool isComplete;

  RebootProgressState({
    required this.currentBatch,
    required this.completedMiners,
    required this.successCount,
    required this.failCount,
    this.isWaiting = false,
    this.countdown = 0,
    this.isComplete = false,
  });
}

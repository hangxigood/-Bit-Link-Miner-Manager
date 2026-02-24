import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/src/controllers/action_controller.dart';
import 'package:frontend/src/controllers/dashboard_controller.dart';

import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/commands.dart' show setMinerPowerMode;
import 'package:frontend/src/services/column_service.dart';
import 'package:frontend/src/widgets/column_settings_dialog.dart';
import 'package:frontend/src/widgets/header_bar.dart';
import 'package:frontend/src/widgets/main_content.dart';
import 'package:frontend/src/widgets/sidebar.dart';
import 'package:frontend/src/widgets/sidebar/ip_ranges_section.dart';
import 'package:frontend/src/widgets/sidebar/pool_config_section.dart';
import 'package:frontend/src/widgets/sidebar/power_control_section.dart';

class DashboardShell extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardShell({super.key, required this.onToggleTheme});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _ipRangesSectionKey = GlobalKey<IpRangesSectionState>();
  final _poolConfigSectionKey = GlobalKey<PoolConfigSectionState>();
  final _powerControlSectionKey = GlobalKey<PowerControlSectionState>();
  late final DashboardController _controller;
  late final ActionController _actionController;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(ColumnService());
    _actionController = ActionController(
      dashboardController: _controller,
      onShowToast: _showToast,
      onTriggerScan: _triggerScan,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<List<Miner>> _triggerScan() async {
    return await _ipRangesSectionKey.currentState?.scanSelectedRanges() ?? [];
  }

  void _configSelected() {
    _runConfig(_controller.selectedMinerIps);
  }

  void _configAll() {
    _runConfig(_controller.miners.map((m) => m.ip).toList());
  }

  Future<void> _runConfig(List<String> ips) async {
    if (ips.isEmpty) {
      _showToast('No miners to configure');
      return;
    }

    final pools = _poolConfigSectionKey.currentState?.getEnabledPools();
    final powerMode = _powerControlSectionKey.currentState?.getPowerMode();

    if (pools == null && powerMode == null) {
      _showToast('Nothing to apply — configure pools or power mode first');
      return;
    }

    _showToast('Applying config to ${ips.length} miner(s)\u2026');

    // Run all IPs concurrently
    final results = await Future.wait(ips.map((ip) async {
      final errors = <String>[];
      if (pools != null) {
        final r = await _actionController.setPoolsForIp(ip, pools);
        if (!r.success) errors.add('pools: ${r.error}');
      }
      if (powerMode != null) {
        final r = await setMinerPowerMode(ip: ip, sleep: powerMode);
        if (!r.success) errors.add('power: ${r.error}');
      }
      return errors.isEmpty;
    }));

    final successCount = results.where((r) => r).length;
    final failCount = results.length - successCount;

    if (failCount == 0) {
      _showToast('Config applied to $successCount miner(s). Miners will reboot.');
    } else {
      _showToast('Config: $successCount ok, $failCount failed. Check credentials.');
    }
  }

  void _openColumnSettings() {
    showDialog(
      context: context,
      builder: (context) => ColumnSettingsDialog(
        currentColumns: _controller.columns,
        onApply: _controller.updateColumns,
        onReset: _controller.resetColumns,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoadingColumns) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              HeaderBar(
                onToggleSidebar: _controller.toggleSidebar,
                onToggleTheme: widget.onToggleTheme,
                onShowColumnSettings: _openColumnSettings,
                onlineCount: _controller.onlineMinersCount,
                totalCount: _controller.totalMinersCount,
                totalHashrate: _controller.totalHashrate,
              ),
              Expanded(
                child: Row(
                  children: [
                     Sidebar(
                      isCollapsed: _controller.isSidebarCollapsed,
                      onScanStart: () => _controller.setScanning(true),
                      onScanComplete: (miners) {
                        _controller.handleScanComplete(miners);
                        _showToast('Scan complete! Found ${miners.length} miners');
                      },
                      onShowToast: _showToast,
                      ipRangesSectionKey: _ipRangesSectionKey,
                      poolConfigSectionKey: _poolConfigSectionKey,
                      powerControlSectionKey: _powerControlSectionKey,
                    ),
                    Expanded(
                      child: MainContent(
                        miners: _controller.paginatedMiners,
                        allMiners: _controller.miners,
                        selectedIps: _controller.selectedMinerIps,
                        onSelectionChanged: _controller.setSelection,
                        searchQuery: _controller.searchQuery,
                        onSearchChanged: _controller.setSearchQuery,
                        statusFilter: _controller.statusFilter,
                        onStatusFilterChanged: _controller.setStatusFilter,
                        sortColumn: _controller.sortColumn,
                        sortAscending: _controller.sortAscending,
                        onSortChanged: _controller.setSort,
                        currentPage: _controller.currentPage,
                        pageSize: _controller.pageSize,
                        totalItems: _controller.totalMinersCount,
                        onPageChanged: _controller.setPage,
                        isScanning: _controller.isScanning,
                        isMonitoring: _controller.isMonitoring,
                        actionController: _actionController,
                        visibleColumns: _controller.columns,
                        blinkingIps: _controller.blinkingIps,
                       onShowColumnSettings: _openColumnSettings,
                        onColumnWidthChanged: _controller.updateColumnWidth,
                        onConfigSelected: _configSelected,
                        onConfigAll: _configAll,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


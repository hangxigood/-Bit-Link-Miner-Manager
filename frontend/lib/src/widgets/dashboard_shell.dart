import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/src/controllers/action_controller.dart';
import 'package:frontend/src/controllers/dashboard_controller.dart';

import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/services/column_service.dart';
import 'package:frontend/src/widgets/column_settings_dialog.dart';
import 'package:frontend/src/widgets/header_bar.dart';
import 'package:frontend/src/widgets/main_content.dart';
import 'package:frontend/src/widgets/sidebar.dart';
import 'package:frontend/src/widgets/sidebar/ip_ranges_section.dart';

class DashboardShell extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardShell({super.key, required this.onToggleTheme});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _ipRangesSectionKey = GlobalKey<IpRangesSectionState>();
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


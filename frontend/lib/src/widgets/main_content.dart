import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/widgets/dashboard_shell.dart';
import 'package:frontend/src/widgets/action_bar.dart';
import 'package:frontend/src/widgets/filter_toolbar.dart';
import 'package:frontend/src/widgets/miner_data_table.dart';

class MainContent extends StatelessWidget {
  final List<Miner> miners;
  final List<Miner> allMiners;
  final List<String> selectedIps;
  final Function(List<String>) onSelectionChanged;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final MinerStatusFilter statusFilter;
  final Function(MinerStatusFilter) onStatusFilterChanged;
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSortChanged;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final Function(int) onPageChanged;
  final bool isScanning;
  final bool isMonitoring;
  final Function(bool) onMonitorToggle;
  final Function(String) onShowToast;
  final Future<void> Function() onTriggerScan;

  const MainContent({
    super.key,
    required this.miners,
    required this.allMiners,
    required this.selectedIps,
    required this.onSelectionChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortChanged,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    required this.isScanning,
    required this.isMonitoring,
    required this.onMonitorToggle,
    required this.onShowToast,
    required this.onTriggerScan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ActionBar(
          selectedIps: selectedIps,
          allMiners: allMiners,
          isScanning: isScanning,
          isMonitoring: isMonitoring,
          onMonitorToggle: onMonitorToggle,
          onShowToast: onShowToast,
          onTriggerScan: onTriggerScan,
        ),
        FilterToolbar(
          searchQuery: searchQuery,
          onSearchChanged: onSearchChanged,
          statusFilter: statusFilter,
          onStatusFilterChanged: onStatusFilterChanged,
          miners: allMiners,
        ),
        Expanded(
          child: MinerDataTable(
            miners: miners,
            selectedIps: selectedIps,
            onSelectionChanged: onSelectionChanged,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onSortChanged: onSortChanged,
            currentPage: currentPage,
            pageSize: pageSize,
            totalItems: totalItems,
            onPageChanged: onPageChanged,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/models/miner_status_filter.dart';
import 'package:frontend/src/models/data_column_config.dart';
import 'package:frontend/src/controllers/action_controller.dart';
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
  final ActionController actionController;
  final List<DataColumnConfig> visibleColumns;
  final Set<String> blinkingIps;
  final VoidCallback onShowColumnSettings;
  final Function(String columnId, double newWidth) onColumnWidthChanged;
  final VoidCallback? onConfigSelected;
  final VoidCallback? onConfigAll;

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
    required this.actionController,
    required this.visibleColumns,
    required this.blinkingIps,
    required this.onShowColumnSettings,
    required this.onColumnWidthChanged,
    this.onConfigSelected,
    this.onConfigAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionBar(
          selectedIps: selectedIps,
          allMiners: allMiners,
          isScanning: isScanning,
          isMonitoring: isMonitoring,
          actionController: actionController,
          blinkingIps: blinkingIps,
          onConfigSelected: onConfigSelected,
          onConfigAll: onConfigAll,
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
            visibleColumns: visibleColumns,
            blinkingIps: blinkingIps,
            onBlinkToggle: (ip, _) => actionController.toggleLocate([ip]),
            onShowColumnSettings: onShowColumnSettings,
            onColumnWidthChanged: onColumnWidthChanged,
          ),
        ),
      ],
    );
  }
}

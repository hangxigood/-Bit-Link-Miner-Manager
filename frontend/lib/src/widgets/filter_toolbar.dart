import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/models/miner_status_filter.dart';
import 'package:frontend/src/theme/app_theme.dart';

class FilterToolbar extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final MinerStatusFilter statusFilter;
  final Function(MinerStatusFilter) onStatusFilterChanged;
  final List<Miner> miners;

  const FilterToolbar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.miners,
  });

  int _getCountForFilter(MinerStatusFilter filter) {
    switch (filter) {
      case MinerStatusFilter.all:
        return miners.length;
      case MinerStatusFilter.online:
        return miners.where((m) => m.status == MinerStatus.active).length;
      case MinerStatusFilter.warning:
        return miners.where((m) => m.status == MinerStatus.warning).length;
      case MinerStatusFilter.error:
        return miners.where((m) => m.status == MinerStatus.warning).length; // Using warning as error
      case MinerStatusFilter.offline:
        return miners.where((m) => m.status == MinerStatus.dead).length;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Search input
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by IP, model, worker, pool...',
                  hintStyle: TextStyle(fontSize: 11),
                  prefixIcon: Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: TextStyle(fontSize: 12),
                onChanged: onSearchChanged,
              ),
            ),
            
            SizedBox(width: 16),
            
            // Status filter buttons
            _buildFilterButton(
              context,
              'All',
              MinerStatusFilter.all,
              _getCountForFilter(MinerStatusFilter.all),
            ),
            SizedBox(width: 6),
            _buildFilterButton(
              context,
              'Online',
              MinerStatusFilter.online,
              _getCountForFilter(MinerStatusFilter.online),
            ),
            SizedBox(width: 6),
            _buildFilterButton(
              context,
              'Warning',
              MinerStatusFilter.warning,
              _getCountForFilter(MinerStatusFilter.warning),
            ),
            SizedBox(width: 6),
            _buildFilterButton(
              context,
              'Error',
              MinerStatusFilter.error,
              _getCountForFilter(MinerStatusFilter.error),
            ),
            SizedBox(width: 6),
            _buildFilterButton(
              context,
              'Offline',
              MinerStatusFilter.offline,
              _getCountForFilter(MinerStatusFilter.offline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    String label,
    MinerStatusFilter filter,
    int count,
  ) {
    final isActive = statusFilter == filter;
    
    return ElevatedButton(
      onPressed: () => onStatusFilterChanged(filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : context.secondarySurface,
        foregroundColor: isActive
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(0, 28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

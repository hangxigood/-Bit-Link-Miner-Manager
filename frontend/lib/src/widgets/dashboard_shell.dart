import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/widgets/header_bar.dart';
import 'package:frontend/src/widgets/sidebar.dart';
import 'package:frontend/src/widgets/sidebar/ip_ranges_section.dart';
import 'package:frontend/src/widgets/main_content.dart';

class DashboardShell extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardShell({super.key, required this.onToggleTheme});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // GlobalKey to access IP ranges section
  final _ipRangesSectionKey = GlobalKey<IpRangesSectionState>();
  
  // Data state
  List<Miner> _miners = [];
  List<String> _selectedMinerIps = [];
  
  // UI state
  bool _isSidebarCollapsed = false;
  bool _isScanning = false;
  bool _isMonitoring = false;
  
  // Filter/Search state
  String _searchQuery = '';
  MinerStatusFilter _statusFilter = MinerStatusFilter.all;
  
  // Sort state
  String _sortColumn = 'ip';
  bool _sortAscending = true;
  
  // Pagination state
  int _currentPage = 0;
  int _pageSize = 50;

  List<Miner> get _filteredMiners {
    return _miners.where((m) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = m.ip.toLowerCase().contains(q) ||
            (m.model?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker1?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker2?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker3?.toLowerCase().contains(q) ?? false) ||
            (m.stats.pool1?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }
      
      // Status filter
      switch (_statusFilter) {
        case MinerStatusFilter.online:
          return m.status == MinerStatus.active;
        case MinerStatusFilter.warning:
          return m.status == MinerStatus.warning;
        case MinerStatusFilter.error:
          return m.status == MinerStatus.warning; // Using warning as error
        case MinerStatusFilter.offline:
          return m.status == MinerStatus.dead;
        case MinerStatusFilter.all:
          return true;
      }
    }).toList();
  }

  List<Miner> get _sortedMiners {
    final miners = List<Miner>.from(_filteredMiners);
    
    miners.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumn) {
        case 'ip':
          comparison = a.ip.compareTo(b.ip);
          break;
        case 'status':
          comparison = a.status.index.compareTo(b.status.index);
          break;
        case 'model':
          comparison = (a.model ?? '').compareTo(b.model ?? '');
          break;
        case 'hashrate_rt':
          comparison = a.stats.hashrateRt.compareTo(b.stats.hashrateRt);
          break;
        case 'hashrate_avg':
          comparison = a.stats.hashrateAvg.compareTo(b.stats.hashrateAvg);
          break;
        case 'uptime':
          comparison = a.stats.uptime.compareTo(b.stats.uptime);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return miners;
  }

  List<Miner> get _paginatedMiners {
    final sorted = _sortedMiners;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, sorted.length);
    
    if (start >= sorted.length) return [];
    return sorted.sublist(start, end);
  }

  void _handleScanComplete(List<Miner> miners) {
    setState(() {
      _miners = miners;
      _isScanning = false;
      _currentPage = 0; // Reset to first page
    });
    
    _showToast('Scan complete! Found ${miners.length} miners');
  }

  void _handleScanStart() {
    setState(() {
      _isScanning = true;
    });
  }

  void _handleSelectionChanged(List<String> selectedIps) {
    setState(() {
      _selectedMinerIps = selectedIps;
    });
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0; // Reset to first page
    });
  }

  void _handleStatusFilterChanged(MinerStatusFilter filter) {
    setState(() {
      _statusFilter = filter;
      _currentPage = 0; // Reset to first page
    });
  }

  void _handleSortChanged(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _handleMonitorToggle(bool enabled) {
    setState(() {
      _isMonitoring = enabled;
    });
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

  Future<void> _triggerScan() async {
    _ipRangesSectionKey.currentState?.scanSelectedRanges();
  }

  @override
  Widget build(BuildContext context) {
    final totalMiners = _filteredMiners.length;
    final onlineMiners = _filteredMiners.where((m) => m.status == MinerStatus.active).length;
    final totalHashrate = _filteredMiners.fold<double>(
      0.0,
      (sum, m) => sum + m.stats.hashrateRt,
    );

    return Scaffold(
      body: Column(
        children: [
          HeaderBar(
            onToggleSidebar: _toggleSidebar,
            onToggleTheme: widget.onToggleTheme,
            onlineCount: onlineMiners,
            totalCount: totalMiners,
            totalHashrate: totalHashrate,
          ),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  isCollapsed: _isSidebarCollapsed,
                  onScanStart: _handleScanStart,
                  onScanComplete: _handleScanComplete,
                  onShowToast: _showToast,
                  ipRangesSectionKey: _ipRangesSectionKey,
                ),
                Expanded(
                  child: MainContent(
                    miners: _paginatedMiners,
                    allMiners: _miners,
                    selectedIps: _selectedMinerIps,
                    onSelectionChanged: _handleSelectionChanged,
                    searchQuery: _searchQuery,
                    onSearchChanged: _handleSearchChanged,
                    statusFilter: _statusFilter,
                    onStatusFilterChanged: _handleStatusFilterChanged,
                    sortColumn: _sortColumn,
                    sortAscending: _sortAscending,
                    onSortChanged: _handleSortChanged,
                    currentPage: _currentPage,
                    pageSize: _pageSize,
                    totalItems: totalMiners,
                    onPageChanged: _handlePageChanged,
                    isScanning: _isScanning,
                    isMonitoring: _isMonitoring,
                    onMonitorToggle: _handleMonitorToggle,
                    onShowToast: _showToast,
                    onTriggerScan: _triggerScan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum MinerStatusFilter {
  all,
  online,
  warning,
  error,
  offline,
}

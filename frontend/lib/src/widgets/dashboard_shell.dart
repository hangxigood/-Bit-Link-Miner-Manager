import 'dart:async';
import 'package:frontend/src/rust/api/models.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/widgets/header_bar.dart';
import 'package:frontend/src/widgets/sidebar.dart';
import 'package:frontend/src/widgets/sidebar/ip_ranges_section.dart';
import 'package:frontend/src/widgets/main_content.dart';
import 'package:frontend/src/rust/api/monitor.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/widgets/column_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/src/constants/column_constants.dart';

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
  
  // Column Persistence & Configuration
  List<DataColumnConfig> _columns = [];
  bool _isLoadingColumns = true;
  
  // Locate / Blink state
  Set<String> _blinkingIps = {};
  
  // UI state
  bool _isSidebarCollapsed = false;
  bool _isScanning = false;
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  
  // Filter/Search state
  String _searchQuery = '';
  MinerStatusFilter _statusFilter = MinerStatusFilter.all;
  
  // Sort state
  String _sortColumn = 'ip';
  bool _sortAscending = true;
  
  // Pagination state
  int _currentPage = 0;
  int _pageSize = 50;
  
  @override
  void initState() {
    super.initState();
    _loadColumnSettings();
  }

  Future<void> _loadColumnSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up old preference keys
      await prefs.remove('miner_table_columns_v1');
      await prefs.remove('miner_table_columns_v2');
      await prefs.remove('miner_table_columns_v3');
      await prefs.remove('miner_table_columns_v4');

      final String? jsonStr = prefs.getString('miner_table_columns_v5');

      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final loaded = jsonList.map((e) => DataColumnConfig(
          id: e['id'],
          label: e['label'],
          visible: e['visible'],
          width: (e['width'] as num?)?.toDouble() ?? 100.0,
        )).toList();

        setState(() {
          _columns = loaded;
          _isLoadingColumns = false;
        });
      } else {
        _resetColumns();
      }
    } catch (e) {
      _resetColumns();
    }
  }

  Future<void> _saveColumnSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _columns.map((c) => {
        'id': c.id,
        'label': c.label,
        'visible': c.visible,
        'width': c.width,
      }).toList();
      await prefs.setString('miner_table_columns_v5', jsonEncode(jsonList));
    } catch (e) {
      // Ignore save errors
    }
  }
  


  void _resetColumns() {
    setState(() {
      _columns = [
        DataColumnConfig(id: ColumnConstants.idIp, label: 'IP Address', visible: true, width: ColumnConstants.widthIp),
        DataColumnConfig(id: ColumnConstants.idStatus, label: 'Status', visible: true, width: ColumnConstants.widthStatus),
        DataColumnConfig(id: ColumnConstants.idLocate, label: 'Locate', visible: true, width: ColumnConstants.widthLocate),
        DataColumnConfig(id: ColumnConstants.idModel, label: 'Model', visible: true, width: ColumnConstants.widthModel),
        DataColumnConfig(id: ColumnConstants.idHashrateRt, label: 'Hashrate', visible: true, width: ColumnConstants.widthHashrate),
        DataColumnConfig(id: ColumnConstants.idHashrateAvg, label: 'Avg Hash', visible: false, width: ColumnConstants.widthHashrate),
        DataColumnConfig(id: ColumnConstants.idTempIn0, label: 'InT-0', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idTempIn1, label: 'InT-1', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idTempIn2, label: 'InT-2', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idTempOut0, label: 'OutT-0', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idTempOut1, label: 'OutT-1', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idTempOut2, label: 'OutT-2', visible: true, width: ColumnConstants.widthTemp),
        DataColumnConfig(id: ColumnConstants.idFan0, label: 'Fan-0', visible: true, width: ColumnConstants.widthFan),
        DataColumnConfig(id: ColumnConstants.idFan1, label: 'Fan-1', visible: true, width: ColumnConstants.widthFan),
        DataColumnConfig(id: ColumnConstants.idFan2, label: 'Fan-2', visible: true, width: ColumnConstants.widthFan),
        DataColumnConfig(id: ColumnConstants.idFan3, label: 'Fan-3', visible: true, width: ColumnConstants.widthFan),
        DataColumnConfig(id: ColumnConstants.idUptime, label: 'Uptime', visible: true, width: ColumnConstants.widthUptime),
        DataColumnConfig(id: ColumnConstants.idPool1, label: 'Pool 1', visible: true, width: ColumnConstants.widthPool),
        DataColumnConfig(id: ColumnConstants.idWorker1, label: 'Worker 1', visible: true, width: ColumnConstants.widthWorker),
        DataColumnConfig(id: ColumnConstants.idPool2, label: 'Pool 2', visible: false, width: ColumnConstants.widthPool),
        DataColumnConfig(id: ColumnConstants.idWorker2, label: 'Worker 2', visible: false, width: ColumnConstants.widthWorker),
        DataColumnConfig(id: ColumnConstants.idPool3, label: 'Pool 3', visible: false, width: ColumnConstants.widthPool),
        DataColumnConfig(id: ColumnConstants.idWorker3, label: 'Worker 3', visible: false, width: ColumnConstants.widthWorker),
        DataColumnConfig(id: ColumnConstants.idMac, label: 'MAC Addr', visible: false, width: ColumnConstants.widthMac),
        DataColumnConfig(id: ColumnConstants.idFirmware, label: 'Firmware', visible: false, width: ColumnConstants.widthMeta),
        DataColumnConfig(id: ColumnConstants.idSoftware, label: 'Software', visible: false, width: ColumnConstants.widthMeta),
        DataColumnConfig(id: ColumnConstants.idHardware, label: 'Hardware', visible: false, width: ColumnConstants.widthMeta),
      ];
      _isLoadingColumns = false;
    });
    _saveColumnSettings(); // Save defaults
  }
  
  void _openColumnSettings() {
    showDialog(
      context: context,
      builder: (context) => ColumnSettingsDialog(
        currentColumns: _columns,
        onApply: (newColumns) {
          setState(() {
            _columns = newColumns;
          });
          _saveColumnSettings();
        },
        onReset: _resetColumns,
      ),
    );
  }

  // ... Filter/Sort getters ...
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
        case 'locate':
          // Sor by blink status
          final aBlink = _blinkingIps.contains(a.ip) ? 1 : 0;
          final bBlink = _blinkingIps.contains(b.ip) ? 1 : 0;
          comparison = aBlink.compareTo(bBlink);
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

  // ... Event Handlers ...

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
    if (enabled) {
      _startMonitorPolling();
    } else {
      _stopMonitorPolling();
    }
  }

  void _startMonitorPolling() {
    _monitorTimer?.cancel();
    // Immediately fetch once
    _fetchMonitoredMiners();
    // Then poll every 5 seconds
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchMonitoredMiners();
    });
  }

  void _stopMonitorPolling() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    // Call stopMonitoring asynchronously
    stopMonitoring().catchError((e) {});
  }

  Future<void> _fetchMonitoredMiners() async {
    try {
      final miners = await getCurrentMiners();
      if (mounted && _isMonitoring) {
        if (miners.isNotEmpty || _miners.isEmpty) {
          setState(() {
            _miners = miners;
          });
        }
      }
    } catch (e) {
      // Silently handle errors
    }
  }
  
  Future<void> _handleBlinkToggle(String ip, bool shouldBlink) async {
    // Optimistic UI update
    setState(() {
      if (shouldBlink) {
        _blinkingIps.add(ip);
      } else {
        _blinkingIps.remove(ip);
      }
    });
    
    // Execute command
    try {
      if (shouldBlink) {
        await executeBatchCommand(targetIps: [ip], command: MinerCommand.blinkLed);
      } else {
        await executeBatchCommand(targetIps: [ip], command: MinerCommand.stopBlink);
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          if (shouldBlink) {
            _blinkingIps.remove(ip);
          } else {
            _blinkingIps.add(ip);
          }
        });
        _showToast('Failed to toggle locate: $e');
      }
    }
  }

  void _handleColumnWidthChanged(String columnId, double newWidth) {
    setState(() {
      final index = _columns.indexWhere((c) => c.id == columnId);
      if (index >= 0) {
        _columns[index] = _columns[index].copyWith(width: newWidth);
      }
    });
    _saveColumnSettings();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingColumns) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
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
            onShowColumnSettings: _openColumnSettings,
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
                    visibleColumns: _columns,
                    blinkingIps: _blinkingIps,
                    onBlinkToggle: _handleBlinkToggle,
                    onShowColumnSettings: _openColumnSettings,
                    onColumnWidthChanged: _handleColumnWidthChanged,
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

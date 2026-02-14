
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:frontend/src/models/data_column_config.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/monitor.dart'; // getCurrentMiners
import 'package:frontend/src/rust/api/commands.dart'; // executeBatchCommand
import 'package:frontend/src/services/column_service.dart';

import 'package:frontend/src/models/miner_status_filter.dart';

class DashboardController extends ChangeNotifier {
  final ColumnService _columnService;

  // Data state
  List<Miner> _miners = [];
  List<String> _selectedMinerIps = [];
  
  // Column Configuration
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
  
  // Getters
  List<Miner> get miners => _miners;
  List<String> get selectedMinerIps => _selectedMinerIps;
  List<DataColumnConfig> get columns => _columns;
  bool get isLoadingColumns => _isLoadingColumns;
  Set<String> get blinkingIps => _blinkingIps;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  bool get isScanning => _isScanning;
  bool get isMonitoring => _isMonitoring;
  String get searchQuery => _searchQuery;
  MinerStatusFilter get statusFilter => _statusFilter;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;

  // Constructor
  DashboardController(this._columnService) {
    _loadColumnSettings();
  }

  // Column Management
  Future<void> _loadColumnSettings() async {
    _columns = await _columnService.loadColumnSettings();
    _isLoadingColumns = false;
    notifyListeners();
  }

  Future<void> saveColumnSettings() async {
    await _columnService.saveColumnSettings(_columns);
  }

  void resetColumns() {
    _columns = _columnService.getDefaultColumns();
    notifyListeners();
    saveColumnSettings();
  }
  
  void updateColumnWidth(String columnId, double newWidth) {
    final index = _columns.indexWhere((c) => c.id == columnId);
    if (index >= 0) {
      _columns[index] = _columns[index].copyWith(width: newWidth);
      notifyListeners();
      saveColumnSettings();
    }
  }

  void updateColumns(List<DataColumnConfig> newColumns) {
    _columns = newColumns;
    notifyListeners();
    saveColumnSettings();
  }

  // Sidebar
  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  // Scanning
  void setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  void handleScanComplete(List<Miner> newMiners) {
    _miners = newMiners;
    _isScanning = false;
    _currentPage = 0;
    notifyListeners();
  }

  // Selection
  void setSelection(List<String> selectedIps) {
    _selectedMinerIps = selectedIps;
    notifyListeners();
  }

  // Search & Filter
  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 0;
    notifyListeners();
  }

  void setStatusFilter(MinerStatusFilter filter) {
    _statusFilter = filter;
    _currentPage = 0;
    notifyListeners();
  }

  // Sorting
  void setSort(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    notifyListeners();
  }

  // Pagination
  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  // Monitoring
  void toggleMonitoring(bool enabled) {
    _isMonitoring = enabled;
    notifyListeners();
    
    if (enabled) {
      _startMonitorPolling();
    } else {
      _stopMonitorPolling();
    }
  }

  void _startMonitorPolling() {
    _monitorTimer?.cancel();
    _fetchMonitoredMiners();
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchMonitoredMiners();
    });
  }

  void _stopMonitorPolling() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    stopMonitoring().catchError((e) {
      // Handle error if needed
    });
  }

  Future<void> _fetchMonitoredMiners() async {
    try {
      final miners = await getCurrentMiners();
      // Only update if we are still monitoring and data changed meaningfully (or just always update for now)
      if (_isMonitoring) {
        if (miners.isNotEmpty || _miners.isEmpty) {
          _miners = miners;
          notifyListeners();
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  // Blink/Locate
  Future<void> toggleBlink(String ip, bool shouldBlink, Function(String) onError) async {
    // Optimistic update
    if (shouldBlink) {
      _blinkingIps.add(ip);
    } else {
      _blinkingIps.remove(ip);
    }
    notifyListeners();

    try {
      if (shouldBlink) {
        await executeBatchCommand(targetIps: [ip], command: MinerCommand.blinkLed);
      } else {
        await executeBatchCommand(targetIps: [ip], command: MinerCommand.stopBlink);
      }
    } catch (e) {
      // Revert on error
      if (shouldBlink) {
        _blinkingIps.remove(ip);
      } else {
        _blinkingIps.add(ip);
      }
      notifyListeners();
      onError(e.toString());
    }
  }

  void updateBlinkStatus(String ip, bool isBlinking) {
    if (isBlinking) {
      _blinkingIps.add(ip);
    } else {
      _blinkingIps.remove(ip);
    }
    notifyListeners();
  }

  // Computed Properties (Moved from Shell)
  
  List<Miner> get filteredMiners {
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
          return m.status == MinerStatus.warning; // Using warning as error (copied logic)
        case MinerStatusFilter.offline:
          return m.status == MinerStatus.dead;
        case MinerStatusFilter.all:
          return true;
      }
    }).toList();
  }

  List<Miner> get sortedMiners {
    final miners = List<Miner>.from(filteredMiners);
    
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
          final aBlink = _blinkingIps.contains(a.ip) ? 1 : 0;
          final bBlink = _blinkingIps.contains(b.ip) ? 1 : 0;
          comparison = aBlink.compareTo(bBlink);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return miners;
  }

  List<Miner> get paginatedMiners {
    final sorted = sortedMiners;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, sorted.length);
    
    if (start >= sorted.length) return [];
    return sorted.sublist(start, end);
  }

  int get totalMinersCount => filteredMiners.length;
  
  int get onlineMinersCount => filteredMiners.where((m) => m.status == MinerStatus.active).length;
  
  double get totalHashrate => filteredMiners.fold<double>(
    0.0,
    (sum, m) => sum + m.stats.hashrateRt,
  );

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/api/scanner.dart';
import 'package:frontend/src/rust/api/commands.dart';

class ControlPanel extends StatefulWidget {
  final Function(List) onScanComplete;
  final List<String> selectedMinerIps;
  final Function(String searchQuery, bool activeOnly, bool warningsOnly)? onFilterChanged;

  const ControlPanel({
    super.key,
    required this.onScanComplete,
    required this.selectedMinerIps,
    this.onFilterChanged,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExpanded = true;

  // Scanner tab state
  final TextEditingController _ipRangeController = TextEditingController();
  bool _isScanning = false;
  String? _scanErrorMessage;

  // Batch actions state
  bool _isExecutingBatch = false;

  // Search/Filter tab state
  final TextEditingController _searchController = TextEditingController();
  bool _activeOnly = false;
  bool _warningsOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _ipRangeController.text = '192.168.1.1-192.168.1.254';
    
    _searchController.addListener(_notifyFilterChange);
  }

  void _notifyFilterChange() {
    widget.onFilterChanged?.call(
      _searchController.text,
      _activeOnly,
      _warningsOnly,
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanErrorMessage = null;
    });

    try {
      final ipRange = _ipRangeController.text.trim();
      
      // Validate first
      await validateIpRange(range: ipRange);
      
      // Start scan
      final miners = await startScan(ipRange: ipRange);
      
      widget.onScanComplete(miners);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan complete! Found ${miners.length} miners'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _scanErrorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _executeBatchCommand(MinerCommand command, String commandName) async {
    if (widget.selectedMinerIps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No miners selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExecutingBatch = true;
    });

    try {
      final results = await executeBatchCommand(
        targetIps: widget.selectedMinerIps,
        command: command,
        credentials: null, // Will use default from settings
      );

      final successCount = results.where((r) => r.success).length;
      final failCount = results.length - successCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$commandName: $successCount succeeded, $failCount failed',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch command failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecutingBatch = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with collapse/expand
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Control Panel',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          // Tabs and content
          if (_isExpanded) ...[
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Scanner', icon: Icon(Icons.search, size: 20)),
                Tab(text: 'Batch Actions', icon: Icon(Icons.settings, size: 20)),
                Tab(text: 'Search/Filter', icon: Icon(Icons.filter_list, size: 20)),
              ],
            ),
            SizedBox(
              height: 120,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScannerTab(),
                  _buildBatchActionsTab(),
                  _buildSearchFilterTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ipRangeController,
              decoration: InputDecoration(
                labelText: 'IP Range',
                hintText: '192.168.1.1-192.168.1.254 or 192.168.1.0/24',
                border: const OutlineInputBorder(),
                errorText: _scanErrorMessage,
                isDense: true,
              ),
              enabled: !_isScanning,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _startScan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionsTab() {
    final hasSelection = widget.selectedMinerIps.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            '${widget.selectedMinerIps.length} miner(s) selected',
            style: TextStyle(
              color: hasSelection ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 24),
          ElevatedButton.icon(
            onPressed: (_isExecutingBatch || !hasSelection)
                ? null
                : () => _executeBatchCommand(MinerCommand.reboot, 'Reboot'),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reboot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: (_isExecutingBatch || !hasSelection)
                ? null
                : () => _executeBatchCommand(MinerCommand.blinkLed, 'Blink LED'),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Blink LED'),
          ),
          if (_isExecutingBatch) ...[
            const SizedBox(width: 16),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchFilterTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'IP, Model, or Worker name...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Active Only'),
            selected: _activeOnly,
            onSelected: (selected) {
              setState(() {
                _activeOnly = selected;
                if (_activeOnly && _warningsOnly) {
                  _warningsOnly = false;
                }
              });
              _notifyFilterChange();
            },
            selectedColor: Colors.green.withOpacity(0.3),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Warnings Only'),
            selected: _warningsOnly,
            onSelected: (selected) {
              setState(() {
                _warningsOnly = selected;
                if (_warningsOnly && _activeOnly) {
                  _activeOnly = false;
                }
              });
              _notifyFilterChange();
            },
            selectedColor: Colors.orange.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipRangeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

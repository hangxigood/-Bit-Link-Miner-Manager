import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/rust/api/scanner.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/services/ip_range_service.dart';

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
  final TextEditingController _newRangeController = TextEditingController();
  bool _isScanning = false;
  String? _scanErrorMessage;
  List<String> _savedRanges = [];
  Set<String> _selectedRanges = {};

  // Batch actions state
  bool _isExecutingBatch = false;

  // Search/Filter tab state
  final TextEditingController _searchController = TextEditingController();
  bool _activeOnly = false;
  bool _warningsOnly = false;

  // Pool config tab state
  bool _pool1Enabled = true;
  bool _pool2Enabled = false;
  bool _pool3Enabled = false;
  final TextEditingController _pool1UrlController = TextEditingController();
  final TextEditingController _pool1SubaccountController = TextEditingController();
  final TextEditingController _pool1PwdController = TextEditingController();
  String _pool1WorkerSuffix = 'ip'; // 'ip', 'no_change', 'empty'
  final TextEditingController _pool2UrlController = TextEditingController();
  final TextEditingController _pool2SubaccountController = TextEditingController();
  final TextEditingController _pool2PwdController = TextEditingController();
  String _pool2WorkerSuffix = 'no_change'; // 'ip', 'no_change', 'empty'
  final TextEditingController _pool3UrlController = TextEditingController();
  final TextEditingController _pool3SubaccountController = TextEditingController();
  final TextEditingController _pool3PwdController = TextEditingController();
  String _pool3WorkerSuffix = 'empty'; // 'ip', 'no_change', 'empty'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _pool1PwdController.text = '123';
    _pool2PwdController.text = '123';
    _pool3PwdController.text = '123';
    
    _searchController.addListener(_notifyFilterChange);
    _loadSavedRanges();
  }

  Future<void> _loadSavedRanges() async {
    final ranges = await IpRangeService.getSavedRanges();
    if (mounted) {
      setState(() {
        _savedRanges = ranges;
        // Auto-select all ranges by default
        _selectedRanges = Set.from(ranges);
      });
    }
  }

  Future<void> _addNewRange() async {
    final range = _newRangeController.text.trim();
    if (range.isEmpty) return;

    try {
      // Validate the range first
      await validateIpRange(range: range);
      await IpRangeService.addRange(range);
      _newRangeController.clear();
      await _loadSavedRanges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added range: $range'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid range: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeRange(String range) async {
    await IpRangeService.removeRange(range);
    _selectedRanges.remove(range);
    await _loadSavedRanges();
  }

  void _notifyFilterChange() {
    widget.onFilterChanged?.call(
      _searchController.text,
      _activeOnly,
      _warningsOnly,
    );
  }

  Future<void> _scanSelectedRanges() async {
    if (_selectedRanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ranges selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanErrorMessage = null;
    });

    try {
      List<dynamic> allMiners = [];
      
      for (final range in _selectedRanges) {
        final miners = await startScan(ipRange: range);
        allMiners.addAll(miners);
      }
      
      widget.onScanComplete(allMiners);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan complete! Found ${allMiners.length} miners across ${_selectedRanges.length} range(s)'),
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
        credentials: null,
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

  void _applyPoolConfig() {
    if (widget.selectedMinerIps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No miners selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate at least one pool is enabled
    if (!_pool1Enabled && !_pool2Enabled && !_pool3Enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable at least one pool'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Backend set_pool command not implemented yet (PRD Phase 4)
    final enabledPools = <String>[];
    if (_pool1Enabled) enabledPools.add('Pool 1 (suffix: $_pool1WorkerSuffix)');
    if (_pool2Enabled) enabledPools.add('Pool 2 (suffix: $_pool2WorkerSuffix)');
    if (_pool3Enabled) enabledPools.add('Pool 3 (suffix: $_pool3WorkerSuffix)');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pool configuration for ${widget.selectedMinerIps.length} miner(s) — coming soon!\n'
          'Enabled: ${enabledPools.join(", ")}',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Scanner', icon: Icon(Icons.search, size: 20)),
                Tab(text: 'Batch Actions', icon: Icon(Icons.settings, size: 20)),
                Tab(text: 'Search/Filter', icon: Icon(Icons.filter_list, size: 20)),
                Tab(text: 'Pool Config', icon: Icon(Icons.dns, size: 20)),
              ],
            ),
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScannerTab(),
                  _buildBatchActionsTab(),
                  _buildSearchFilterTab(),
                  _buildPoolConfigTab(),
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
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Saved ranges list with checkboxes
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'IP Ranges',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedRanges.length == _savedRanges.length) {
                            _selectedRanges.clear();
                          } else {
                            _selectedRanges = Set.from(_savedRanges);
                          }
                        });
                      },
                      icon: const Icon(Icons.select_all, size: 14),
                      label: Text(
                        _selectedRanges.length == _savedRanges.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      itemCount: _savedRanges.length,
                      itemBuilder: (context, index) {
                        final range = _savedRanges[index];
                        return CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(range, style: const TextStyle(fontSize: 12)),
                          value: _selectedRanges.contains(range),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedRanges.add(range);
                              } else {
                                _selectedRanges.remove(range);
                              }
                            });
                          },
                          secondary: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => _removeRange(range),
                            iconSize: 16,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            padding: EdgeInsets.zero,
                            color: Colors.red[300],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Add new range row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newRangeController,
                        decoration: const InputDecoration(
                          hintText: 'Add new range...',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onSubmitted: (_) => _addNewRange(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _addNewRange,
                      icon: const Icon(Icons.add_circle),
                      tooltip: 'Add range',
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Scan button and status
          SizedBox(
            width: 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanSelectedRanges,
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
                  label: Text(_isScanning ? 'Scanning...' : 'Scan Selected'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_selectedRanges.length} range(s) selected',
                  style: TextStyle(
                    fontSize: 11,
                    color: _selectedRanges.isEmpty ? Colors.red[300] : Colors.green[300],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_scanErrorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _scanErrorMessage!,
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
            selectedColor: Colors.green.withValues(alpha: 0.3),
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
            selectedColor: Colors.orange.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolConfigTab() {
    final hasSelection = widget.selectedMinerIps.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pool 1
          _buildPoolRow(
            poolNumber: 1,
            enabled: _pool1Enabled,
            onEnabledChanged: (val) => setState(() => _pool1Enabled = val ?? false),
            urlController: _pool1UrlController,
            subaccountController: _pool1SubaccountController,
            pwdController: _pool1PwdController,
            workerSuffix: _pool1WorkerSuffix,
            onWorkerSuffixChanged: (val) => setState(() => _pool1WorkerSuffix = val),
          ),
          const SizedBox(height: 8),
          // Pool 2
          _buildPoolRow(
            poolNumber: 2,
            enabled: _pool2Enabled,
            onEnabledChanged: (val) => setState(() => _pool2Enabled = val ?? false),
            urlController: _pool2UrlController,
            subaccountController: _pool2SubaccountController,
            pwdController: _pool2PwdController,
            workerSuffix: _pool2WorkerSuffix,
            onWorkerSuffixChanged: (val) => setState(() => _pool2WorkerSuffix = val),
          ),
          const SizedBox(height: 8),
          // Pool 3
          _buildPoolRow(
            poolNumber: 3,
            enabled: _pool3Enabled,
            onEnabledChanged: (val) => setState(() => _pool3Enabled = val ?? false),
            urlController: _pool3UrlController,
            subaccountController: _pool3SubaccountController,
            pwdController: _pool3PwdController,
            workerSuffix: _pool3WorkerSuffix,
            onWorkerSuffixChanged: (val) => setState(() => _pool3WorkerSuffix = val),
          ),
          const SizedBox(height: 12),
          // Apply button
          Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _applyPoolConfig,
                icon: const Icon(Icons.send, size: 16),
                label: Text(
                  hasSelection ? 'Apply (${widget.selectedMinerIps.length})' : 'Apply',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelection ? Colors.deepPurple : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoolRow({
    required int poolNumber,
    required bool enabled,
    required ValueChanged<bool?> onEnabledChanged,
    required TextEditingController urlController,
    required TextEditingController subaccountController,
    required TextEditingController pwdController,
    required String workerSuffix,
    required ValueChanged<String> onWorkerSuffixChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: enabled,
          onChanged: onEnabledChanged,
          visualDensity: VisualDensity.compact, 
        ),
        Text('Pool $poolNumber:', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8), 
        Expanded(
          flex: 5,
          child: TextField(
            controller: urlController,
            enabled: enabled,
            decoration: const InputDecoration(
              hintText: 'eu.ss.btc.com:1800',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: subaccountController,
            enabled: enabled,
            decoration: const InputDecoration(
              hintText: 'SubAccount:',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: pwdController,
            enabled: enabled,
            decoration: const InputDecoration(
              hintText: 'PWD:',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Worker Suffix:',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
        const SizedBox(width: 4),
        _buildPoolRadioOption('IP', 'ip', workerSuffix, onWorkerSuffixChanged, enabled),
        const SizedBox(width: 4),
        _buildPoolRadioOption('No Change', 'no_change', workerSuffix, onWorkerSuffixChanged, enabled),
        const SizedBox(width: 4),
        _buildPoolRadioOption('Empty', 'empty', workerSuffix, onWorkerSuffixChanged, enabled),
      ],
    );
  }

  Widget _buildPoolRadioOption(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged,
    bool enabled,
  ) {
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: currentValue,
            onChanged: enabled ? (val) => onChanged(val ?? 'ip') : null,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled ? null : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newRangeController.dispose();
    _searchController.dispose();
    _pool1UrlController.dispose();
    _pool1SubaccountController.dispose();
    _pool1PwdController.dispose();
    _pool2UrlController.dispose();
    _pool2SubaccountController.dispose();
    _pool2PwdController.dispose();
    _pool3UrlController.dispose();
    _pool3SubaccountController.dispose();
    _pool3PwdController.dispose();
    super.dispose();
  }
}

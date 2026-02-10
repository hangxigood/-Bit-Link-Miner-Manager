import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/scanner.dart';
import 'package:frontend/src/services/ip_range_service.dart';
import 'package:frontend/src/theme/app_theme.dart';

class IpRangesSection extends StatefulWidget {
  final VoidCallback onScanStart;
  final Function(List<Miner>) onScanComplete;
  final Function(String) onShowToast;

  const IpRangesSection({
    super.key,
    required this.onScanStart,
    required this.onScanComplete,
    required this.onShowToast,
  });

  @override
  State<IpRangesSection> createState() => IpRangesSectionState();
}

class IpRangesSectionState extends State<IpRangesSection> {
  List<String> _ranges = [];
  Set<String> _selectedRanges = {};
  bool _onlyShowSuccessful = false;
  bool _isScanning = false;
  
  final _startIpController = TextEditingController();
  final _endIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRanges();
  }

  @override
  void dispose() {
    _startIpController.dispose();
    _endIpController.dispose();
    super.dispose();
  }

  // Public method to trigger scan from outside
  Future<void> scanSelectedRanges() async {
    await _scanSelectedRanges();
  }

  Future<void> _loadRanges() async {
    final ranges = await IpRangeService.getSavedRanges();
    setState(() {
      _ranges = ranges;
      // Select all by default
      _selectedRanges = Set.from(ranges);
    });
  }

  Future<void> _addRange() async {
    final start = _startIpController.text.trim();
    final end = _endIpController.text.trim();
    
    if (start.isEmpty || end.isEmpty) {
      widget.onShowToast('Please enter both start and end IP');
      return;
    }
    
    final range = '$start-$end';
    await IpRangeService.addRange(range);
    await _loadRanges();
    
    _startIpController.clear();
    _endIpController.clear();
  }

  Future<void> _removeRange(String range) async {
    await IpRangeService.removeRange(range);
    await _loadRanges();
  }

  Future<void> _scanSelectedRanges() async {
    if (_selectedRanges.isEmpty) {
      widget.onShowToast('No IP ranges selected');
      return;
    }

    setState(() {
      _isScanning = true;
    });
    widget.onScanStart();

    try {
      List<Miner> allMiners = [];
      
      for (final range in _selectedRanges) {
        final miners = await startScan(ipRange: range);
        allMiners.addAll(miners);
      }
      
      widget.onScanComplete(allMiners);
    } catch (e) {
      widget.onShowToast('Scan failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedRanges = Set.from(_ranges);
      } else {
        _selectedRanges.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.router, size: 16, color: context.mutedText),
            SizedBox(width: 6),
            Text(
              'IP Ranges',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.secondarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_ranges.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: context.mutedText,
                ),
              ),
            ),
            Spacer(),
            Checkbox(
              value: _selectedRanges.length == _ranges.length && _ranges.isNotEmpty,
              tristate: true,
              onChanged: _toggleAll,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: 4),
            TextButton.icon(
              onPressed: () {
                widget.onShowToast('Auto-import not implemented yet');
              },
              icon: Icon(Icons.cloud_download, size: 14),
              label: Text('Auto'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size(0, 24),
                textStyle: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Add range inputs
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startIpController,
                decoration: InputDecoration(
                  hintText: 'Start IP',
                  hintStyle: TextStyle(fontSize: 11),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('~', style: TextStyle(color: context.mutedText)),
            ),
            Expanded(
              child: TextField(
                controller: _endIpController,
                decoration: InputDecoration(
                  hintText: 'End IP',
                  hintStyle: TextStyle(fontSize: 11),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.add, size: 18),
              onPressed: _addRange,
              tooltip: 'Add range',
              padding: EdgeInsets.all(6),
              constraints: BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Ranges list
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: context.secondarySurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.border),
          ),
          child: _ranges.isEmpty
              ? Center(
                  child: Text(
                    'No IP ranges',
                    style: TextStyle(fontSize: 11, color: context.mutedText),
                  ),
                )
              : ListView.builder(
                  itemCount: _ranges.length,
                  itemBuilder: (context, index) {
                    final range = _ranges[index];
                    final isSelected = _selectedRanges.contains(range);
                    
                    return MouseRegion(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedRanges.add(range);
                                  } else {
                                    _selectedRanges.remove(range);
                                  }
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                range,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 16),
                              onPressed: () => _removeRange(range),
                              tooltip: 'Delete',
                              padding: EdgeInsets.all(4),
                              constraints: BoxConstraints(),
                              style: IconButton.styleFrom(
                                foregroundColor: context.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        SizedBox(height: 8),
        
        // Only show successful checkbox
        Row(
          children: [
            Checkbox(
              value: _onlyShowSuccessful,
              onChanged: (value) {
                setState(() {
                  _onlyShowSuccessful = value ?? false;
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: 6),
            Text(
              'Only show successful miners',
              style: TextStyle(fontSize: 11, color: context.mutedText),
            ),
          ],
        ),
      ],
    );
  }
}

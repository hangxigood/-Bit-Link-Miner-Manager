import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/scanner.dart';

class ScannerControlPanel extends StatefulWidget {
  final Function(List) onScanComplete;

  const ScannerControlPanel({super.key, required this.onScanComplete});

  @override
  State<ScannerControlPanel> createState() => _ScannerControlPanelState();
}

class _ScannerControlPanelState extends State<ScannerControlPanel> {
  final TextEditingController _ipRangeController = TextEditingController();
  bool _isScanning = false;
  bool _isExpanded = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default IP range
    _ipRangeController.text = '192.168.1.1-192.168.1.254';
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final ipRange = _ipRangeController.text.trim();
      
      // Validate first
      final validation = await validateIpRange(range: ipRange);
      
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
        _errorMessage = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ExpansionTile(
        title: const Text(
          'Network Scanner',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        trailing: _isExpanded
            ? null
            : ElevatedButton.icon(
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
                label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipRangeController,
                    decoration: InputDecoration(
                      labelText: 'IP Range',
                      hintText: '192.168.1.1-192.168.1.254 or 192.168.1.0/24',
                      border: const OutlineInputBorder(),
                      errorText: _errorMessage,
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipRangeController.dispose();
    super.dispose();
  }
}

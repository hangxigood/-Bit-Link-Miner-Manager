import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

class FirmwareDialog extends StatefulWidget {
  final List<String> targetIps;

  const FirmwareDialog({super.key, required this.targetIps});

  @override
  State<FirmwareDialog> createState() => _FirmwareDialogState();
}

class _FirmwareDialogState extends State<FirmwareDialog> {
  String _fileSource = 'Local File';
  final _filePathController = TextEditingController();
  bool _isUploading = false;
  double _progress = 0.0;
  String _statusText = '';

  final List<String> _fileSources = ['Local File', 'HTTP URL', 'FTP Server'];

  @override
  void dispose() {
    _filePathController.dispose();
    super.dispose();
  }

  void _startUpgrade() {
    setState(() {
      _statusText = 'Firmware upgrade not implemented yet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Firmware Upgrade'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upgrading ${widget.targetIps.length} miners',
              style: TextStyle(fontSize: 12, color: context.mutedText),
            ),
            SizedBox(height: 16),
            
            // File source dropdown
            DropdownButtonFormField<String>(
              value: _fileSource,
              decoration: InputDecoration(
                labelText: 'File Source',
                border: OutlineInputBorder(),
              ),
              items: _fileSources.map((source) {
                return DropdownMenuItem(
                  value: source,
                  child: Text(source),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _fileSource = value!;
                });
              },
            ),
            
            SizedBox(height: 12),
            
            // File path/URL input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filePathController,
                    decoration: InputDecoration(
                      labelText: _fileSource == 'Local File' ? 'File Path' : 'URL',
                      hintText: _fileSource == 'Local File'
                          ? '/path/to/firmware.bin'
                          : 'http://example.com/firmware.bin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_fileSource == 'Local File') ...[
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // File picker not implemented
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('File picker not implemented')),
                      );
                    },
                    icon: Icon(Icons.folder_open, size: 16),
                    label: Text('Browse'),
                  ),
                ],
              ],
            ),
            
            SizedBox(height: 16),
            
            // Progress bar
            if (_isUploading) ...[
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 8),
            ],
            
            // Status text
            if (_statusText.isNotEmpty) ...[
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedText,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _startUpgrade,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text('Start Upgrade'),
        ),
      ],
    );
  }
}

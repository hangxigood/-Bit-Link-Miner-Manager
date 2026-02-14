import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/src/services/batch_settings_service.dart';
import 'package:frontend/src/theme/app_theme.dart';

class RebootConfigDialog extends StatefulWidget {
  final int totalMiners;
  final String title;

  const RebootConfigDialog({
    super.key,
    required this.totalMiners,
    required this.title,
  });

  @override
  State<RebootConfigDialog> createState() => _RebootConfigDialogState();
}

class _RebootConfigDialogState extends State<RebootConfigDialog> {
  late TextEditingController _batchSizeController;
  late TextEditingController _batchDelayController;
  int _savedBatchSize = 10;
  int _savedBatchDelay = 5;

  @override
  void initState() {
    super.initState();
    _batchSizeController = TextEditingController();
    _batchDelayController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _savedBatchSize = await BatchSettingsService.getBatchSize();
    _savedBatchDelay = await BatchSettingsService.getBatchDelay();
    if (mounted) {
      _batchSizeController.text = _savedBatchSize.toString();
      _batchDelayController.text = _savedBatchDelay.toString();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _batchSizeController.dispose();
    _batchDelayController.dispose();
    super.dispose();
  }

  Future<void> _saveSettingsAndPop(String result) async {
    final batchSize = (int.tryParse(_batchSizeController.text) ?? _savedBatchSize).clamp(1, 50);
    final batchDelay = (int.tryParse(_batchDelayController.text) ?? _savedBatchDelay).clamp(1, 60);

    await BatchSettingsService.setBatchSize(batchSize);
    await BatchSettingsService.setBatchDelay(batchDelay);

    if (mounted) {
      Navigator.pop(context, {
        'action': result,
        'batchSize': batchSize,
        'batchDelay': batchDelay,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure staggered reboot to avoid power surges, or reboot all at once.',
              style: TextStyle(fontSize: 13, color: context.mutedText),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _batchSizeController,
                    decoration: InputDecoration(
                      labelText: 'Batch Size',
                      helperText: 'Miners per batch (1–50)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.groups, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _batchDelayController,
                    decoration: InputDecoration(
                      labelText: 'Delay (seconds)',
                      helperText: 'Wait between batches (1–60)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ListenableBuilder(
              listenable: Listenable.merge([_batchSizeController, _batchDelayController]),
              builder: (context, _) {
                final batchSize = (int.tryParse(_batchSizeController.text) ?? _savedBatchSize).clamp(1, 50);
                final totalBatches = (widget.totalMiners / batchSize).ceil();
                final delay = int.tryParse(_batchDelayController.text) ?? _savedBatchDelay;
                final totalTime = (totalBatches - 1) * delay;
                return Text(
                  '$totalBatches batches · ~${totalTime}s total wait',
                  style: TextStyle(fontSize: 11, color: context.mutedText),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _saveSettingsAndPop('staggered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text('Staggered Reboot'),
        ),
        ElevatedButton(
          onPressed: () => _saveSettingsAndPop('at_once'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.error,
            foregroundColor: Colors.white,
          ),
          child: Text('Reboot at Once'),
        ),
      ],
    );
  }
}

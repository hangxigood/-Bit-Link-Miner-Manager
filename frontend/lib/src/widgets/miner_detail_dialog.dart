import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/rust/api/models.dart';

class MinerDetailDialog extends StatefulWidget {
  final Miner miner;

  const MinerDetailDialog({super.key, required this.miner});

  @override
  State<MinerDetailDialog> createState() => _MinerDetailDialogState();
}

class _MinerDetailDialogState extends State<MinerDetailDialog> {
  bool _isExecuting = false;
  String? _lastResult;
  Color? _resultColor;

  Future<void> _executeCommand(MinerCommand command) async {
    setState(() {
      _isExecuting = true;
      _lastResult = null;
    });

    try {
      final results = await executeBatchCommand(
        targetIps: [widget.miner.ip],
        command: command,
      );

      if (!mounted) return;

      final result = results.first;
      setState(() {
        _isExecuting = false;
        if (result.success) {
          _lastResult = 'Command sent successfully!';
          _resultColor = Colors.green;
        } else {
          _lastResult = 'Error: ${result.error ?? "Unknown error"}';
          _resultColor = Colors.red;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExecuting = false;
        _lastResult = 'Failed to execute: $e';
        _resultColor = Colors.red;
      });
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${hours}h ${minutes}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.developer_board),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.miner.ip, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.miner.model ?? "Unknown Model", style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          _buildStatusBadge(widget.miner.status),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('Performance'),
              _buildInfoRow('Hashrate (RT)', '${widget.miner.stats.hashrateRt.toStringAsFixed(2)} TH/s'),
              _buildInfoRow('Hashrate (Avg)', '${widget.miner.stats.hashrateAvg.toStringAsFixed(2)} TH/s'),
              _buildInfoRow('Uptime', _formatDuration(widget.miner.stats.uptime.toInt())),

              const SizedBox(height: 16),
              _buildSectionTitle('Thermals'),
              _buildTempGrid('Chip Temps', widget.miner.stats.temperatureChip),
              const SizedBox(height: 8),
              _buildTempGrid('PCB Temps', widget.miner.stats.temperaturePcb),

              const SizedBox(height: 16),
              _buildSectionTitle('Cooling'),
              _buildFanList(widget.miner.stats.fanSpeeds),

              const SizedBox(height: 16),
              _buildSectionTitle('System Info'),
              _buildInfoRow('Hardware', widget.miner.stats.hardware ?? '--'),
              _buildInfoRow('Firmware', widget.miner.stats.firmware ?? '--'),
              _buildInfoRow('Software', widget.miner.stats.software ?? '--'),

              const SizedBox(height: 16),
              _buildSectionTitle('Mining Pools'),
              if (widget.miner.stats.pool1 != null) ...[
                _buildPoolInfo('Pool 1', widget.miner.stats.pool1!, widget.miner.stats.worker1),
                const SizedBox(height: 4),
              ],
              if (widget.miner.stats.pool2 != null) ...[
                _buildPoolInfo('Pool 2', widget.miner.stats.pool2!, widget.miner.stats.worker2),
                const SizedBox(height: 4),
              ],
              if (widget.miner.stats.pool3 != null) ...[
                _buildPoolInfo('Pool 3', widget.miner.stats.pool3!, widget.miner.stats.worker3),
              ],
              if (widget.miner.stats.pool1 == null && 
                  widget.miner.stats.pool2 == null && 
                  widget.miner.stats.pool3 == null)
                const Text('No pool information available', 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),

              if (_lastResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _resultColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _resultColor ?? Colors.grey),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _resultColor == Colors.green ? Icons.check_circle : Icons.error,
                        color: _resultColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastResult!,
                          style: TextStyle(color: _resultColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isExecuting)
          const CircularProgressIndicator()
        else ...[
          TextButton.icon(
            onPressed: () => _executeCommand(MinerCommand.blinkLed),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Blink LED'),
          ),
          TextButton.icon(
            onPressed: () => _executeCommand(MinerCommand.reboot),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reboot'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTempGrid(String label, List<double> temps) {
    if (temps.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: temps.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTempColor(t).withOpacity(0.1),
              border: Border.all(color: _getTempColor(t), width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${t.toStringAsFixed(0)}°C',
              style: TextStyle(fontSize: 11, color: _getTempColor(t), fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildFanList(List<int> fans) {
    if (fans.isEmpty) return const Text('No fans detected', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    
    return Wrap(
      spacing: 8,
      children: fans.asMap().entries.map((entry) {
        return Chip(
          avatar: const Icon(Icons.cyclone, size: 14),
          label: Text('${entry.value} RPM'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Color _getTempColor(double temp) {
    if (temp >= 85) return Colors.red;
    if (temp >= 75) return Colors.orange;
    return Colors.green;
  }

  Widget _buildStatusBadge(MinerStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case MinerStatus.active:
        color = Colors.green;
        text = 'ACTIVE';
        break;
      case MinerStatus.warning:
        color = Colors.orange;
        text = 'WARNING';
        break;
      case MinerStatus.dead:
        color = Colors.red;
        text = 'OFFLINE';
        break;
      case MinerStatus.scanning:
        color = Colors.blue;
        text = 'SCANNING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPoolInfo(String label, String poolUrl, String? worker) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, 
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.cloud_queue, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(poolUrl, 
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (worker != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(worker, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

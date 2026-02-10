import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/widgets/miner_detail_dialog.dart';

class MinerDataTable extends StatelessWidget {
  final List<Miner> miners;
  final List<String> selectedIps;
  final Function(List<String>) onSelectionChanged;
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSortChanged;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final Function(int) onPageChanged;

  const MinerDataTable({
    super.key,
    required this.miners,
    required this.selectedIps,
    required this.onSelectionChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortChanged,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
  });

  void _toggleSelectAll() {
    if (selectedIps.length == miners.length && miners.isNotEmpty) {
      onSelectionChanged([]);
    } else {
      onSelectionChanged(miners.map((m) => m.ip).toList());
    }
  }

  void _toggleSelection(String ip) {
    final newSelection = List<String>.from(selectedIps);
    if (newSelection.contains(ip)) {
      newSelection.remove(ip);
    } else {
      newSelection.add(ip);
    }
    onSelectionChanged(newSelection);
  }

  double _getMaxTemp(MinerStats stats) {
    double maxChip = stats.temperatureChip.isEmpty ? 0 : stats.temperatureChip.reduce((a, b) => a > b ? a : b);
    double maxPcb = stats.temperaturePcb.isEmpty ? 0 : stats.temperaturePcb.reduce((a, b) => a > b ? a : b);
    return maxChip > maxPcb ? maxChip : maxPcb;
  }

  Color _getTempColor(BuildContext context, double temp) {
    if (temp < 75) return context.success;
    if (temp < 85) return context.warning;
    return context.error;
  }

  String _formatUptime(BigInt uptime) {
    final seconds = uptime.toInt();
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _stripProtocol(String? url) {
    if (url == null) return '-';
    return url.replaceAll(RegExp(r'^(stratum\+tcp://|http://|https://)'), '');
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / pageSize).ceil();
    final startItem = currentPage * pageSize + 1;
    final endItem = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Column(
      children: [
        // Table header + body
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    ...miners.asMap().entries.map((entry) {
                      final index = entry.key;
                      final miner = entry.value;
                      return _buildRow(context, miner, index);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Footer
        _buildFooter(context, startItem, endItem, totalPages),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.secondarySurface,
        border: Border(
          bottom: BorderSide(color: context.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Select all checkbox
          SizedBox(
            width: 50,
            child: Checkbox(
              value: miners.isNotEmpty && selectedIps.length == miners.length,
              tristate: true,
              onChanged: (_) => _toggleSelectAll(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          _buildHeaderCell('IP Address', 'ip', 130),
          _buildHeaderCell('Status', 'status', 100),
          _buildHeaderCell('MAC Address', 'mac', 140),
          _buildHeaderCell('Model', 'model', 160),
          _buildHeaderCell('RT Hash', 'hashrate_rt', 100, align: TextAlign.right),
          _buildHeaderCell('Avg Hash', 'hashrate_avg', 100, align: TextAlign.right),
          _buildHeaderCell('Temp', 'temp', 80, align: TextAlign.right),
          _buildHeaderCell('Fans', 'fan', 140, align: TextAlign.right),
          _buildHeaderCell('Uptime', 'uptime', 100, align: TextAlign.right),
          _buildHeaderCell('Pool 1', 'pool1', 180),
          _buildHeaderCell('Worker 1', 'worker1', 140),
          _buildHeaderCell('Pool 2', 'pool2', 180),
          _buildHeaderCell('Worker 2', 'worker2', 140),
          _buildHeaderCell('Pool 3', 'pool3', 180),
          _buildHeaderCell('Worker 3', 'worker3', 140),
          _buildHeaderCell('Firmware', 'firmware', 140),
          _buildHeaderCell('Software', 'software', 140),
          _buildHeaderCell('Hardware', 'hardware', 140),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String column, double width, {TextAlign align = TextAlign.left}) {
    return Builder(
      builder: (context) {
        final isActive = sortColumn == column;
        
        return InkWell(
          onTap: () => onSortChanged(column),
          child: Container(
            width: width,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                SizedBox(width: 4),
                Icon(
                  isActive
                      ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                      : Icons.unfold_more,
                  size: 14,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : context.mutedText.withOpacity(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, Miner miner, int index) {
    final isSelected = selectedIps.contains(miner.ip);
    final isEven = index % 2 == 0;
    final maxTemp = _getMaxTemp(miner.stats);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MinerDetailDialog(miner: miner),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : (isEven ? context.secondarySurface.withOpacity(0.3) : Colors.transparent),
          border: Border(
            bottom: BorderSide(color: context.border.withOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 50,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(miner.ip),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            _buildCell(miner.ip, 130, mono: true),
            _buildStatusCell(context, miner.status, 100),
            _buildCell(miner.stats.macAddress ?? '-', 140, mono: true),
            _buildCell(miner.model ?? '-', 160),
            _buildCell('${miner.stats.hashrateRt.toStringAsFixed(2)} TH/s', 100, mono: true, align: TextAlign.right),
            _buildCell('${miner.stats.hashrateAvg.toStringAsFixed(2)} TH/s', 100, mono: true, align: TextAlign.right),
            _buildTempCell(context, maxTemp, 80),
            _buildCell(
              miner.stats.fanSpeeds.isEmpty ? '-' : miner.stats.fanSpeeds.join(' | '),
              140,
              mono: true,
              align: TextAlign.right,
            ),
            _buildCell(_formatUptime(miner.stats.uptime), 100, mono: true, align: TextAlign.right),
            _buildPoolCell(context, miner.stats.pool1, 180),
            _buildCell(miner.stats.worker1 ?? '-', 140),
            _buildPoolCell(context, miner.stats.pool2, 180),
            _buildCell(miner.stats.worker2 ?? '-', 140),
            _buildPoolCell(context, miner.stats.pool3, 180),
            _buildCell(miner.stats.worker3 ?? '-', 140),
            _buildCell(miner.stats.firmware ?? '-', 140),
            _buildCell(miner.stats.software ?? '-', 140),
            _buildCell(miner.stats.hardware ?? '-', 140),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, double width, {bool mono = false, bool muted = false, TextAlign align = TextAlign.left, String? tooltip}) {
    return Builder(
      builder: (context) {
        final widget = Container(
          width: width,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          alignment: align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontFamily: mono ? 'monospace' : null,
              color: muted ? context.mutedText : Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );

        if (tooltip != null && tooltip.isNotEmpty) {
          return Tooltip(message: tooltip, child: widget);
        }
        return widget;
      },
    );
  }

  Widget _buildStatusCell(BuildContext context, MinerStatus status, double width) {
    Color color;
    String label;
    
    switch (status) {
      case MinerStatus.active:
        color = context.success;
        label = 'Online';
        break;
      case MinerStatus.warning:
        color = context.warning;
        label = 'Warning';
        break;
      case MinerStatus.dead:
        color = context.error;
        label = 'Offline';
        break;
      case MinerStatus.scanning:
        color = context.mutedText;
        label = 'Scanning';
        break;
    }

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTempCell(BuildContext context, double temp, double width) {
    final color = _getTempColor(context, temp);
    final percentage = (temp / 100).clamp(0.0, 1.0);

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${temp.toStringAsFixed(0)}°C',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: context.secondarySurface,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: percentage,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolCell(BuildContext context, String? poolUrl, double width) {
    final stripped = _stripProtocol(poolUrl);

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Tooltip(
        message: poolUrl ?? '',
        child: Text(
          stripped,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, int startItem, int endItem, int totalPages) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.secondarySurface,
        border: Border(
          top: BorderSide(color: context.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$totalItems miners',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 16),
          Text(
            '${selectedIps.length} selected',
            style: TextStyle(fontSize: 12, color: context.mutedText),
          ),
          Spacer(),
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: TextStyle(fontSize: 12, color: context.mutedText),
          ),
          SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.chevron_left, size: 20),
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            tooltip: 'Previous page',
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 20),
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

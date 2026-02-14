
import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/services/credentials_service.dart';
import 'package:frontend/src/widgets/column_settings_dialog.dart';
import 'package:frontend/src/models/data_column_config.dart';
import 'package:frontend/src/constants/column_constants.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final List<DataColumnConfig> visibleColumns;
  final Set<String> blinkingIps;
  final Function(String ip, bool isBlinking) onBlinkToggle;
  final VoidCallback onShowColumnSettings;
  final Function(String columnId, double newWidth) onColumnWidthChanged;

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
    required this.visibleColumns,
    required this.blinkingIps,
    required this.onBlinkToggle,
    required this.onShowColumnSettings,
    required this.onColumnWidthChanged,
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

  String _formatSingleTemp(double? temp) {
    if (temp == null) return '-';
    return temp.toStringAsFixed(1);
  }

  String _formatTempRange(double? min, double? max) {
    if (min == null && max == null) return '-';
    if (min == null) return max!.toInt().toString();
    if (max == null) return min.toInt().toString();
    if (min == max) return min.toInt().toString();
    return '${min.toInt()} | ${max.toInt()}';
  }

  String _formatSingleFan(int? fan) {
    if (fan == null) return '-';
    return fan.toString();
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
  
  double _getColumnWidth(String id) {
    try {
      return visibleColumns.firstWhere((c) => c.id == id).width;
    } catch (_) {
      return 100.0;
    }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate total content width (checkbox + all visible columns)
                final contentWidth = 50.0 +
                    visibleColumns
                        .where((c) => c.visible)
                        .fold<double>(0, (sum, col) => sum + _getColumnWidth(col.id));

                // Use the larger of viewport width or content width
                final tableWidth = contentWidth > constraints.maxWidth
                    ? contentWidth
                    : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
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
                );
              },
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
          // Dynamic columns
          ...visibleColumns.where((c) => c.visible).map((col) {
            TextAlign align = TextAlign.left;
            // Right-align numeric columns
            if (['hashrate_rt', 'hashrate_avg',
                 'temp_in_0', 'temp_in_1', 'temp_in_2',
                 'temp_out_0', 'temp_out_1', 'temp_out_2',
                 'fan_0', 'fan_1', 'fan_2', 'fan_3',
                 'uptime'].contains(col.id)) {
              align = TextAlign.right;
            }
            return _buildHeaderCell(col.label, col.id, _getColumnWidth(col.id), align: align);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String column, double width, {TextAlign align = TextAlign.left}) {
    return Builder(
      builder: (context) {
        final isActive = sortColumn == column;
        
        return Container(
          width: width,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: context.border.withOpacity(0.3), width: 1),
            ),
          ),
          child: Stack(
            children: [
              InkWell(
                onTap: () => onSortChanged(column),
                child: Container(
                  width: width,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isActive ? Theme.of(context).colorScheme.primary : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (isActive)
                        Icon(
                          sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      final newWidth = width + details.delta.dx;
                      if (newWidth >= 50) {
                        onColumnWidthChanged(column, newWidth);
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, Miner miner, int index) {
    final isSelected = selectedIps.contains(miner.ip);
    final isEven = index % 2 == 0;

    return InkWell(
      onTap: () async {
        // Get credentials from settings
        final username = await CredentialsService.getUsername();
        final password = await CredentialsService.getPassword();
        
        // Embed credentials for auto-login (Digest Auth)
        final url = Uri.parse('http://$username:$password@${miner.ip}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open http://${miner.ip}')),
            );
          }
        }
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
            // Dynamic cells
            ...visibleColumns.where((c) => c.visible).map((col) {
              return _buildCellForId(context, miner, col.id);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCellForId(BuildContext context, Miner miner, String colId) {
    final width = _getColumnWidth(colId);

    switch (colId) {
      case ColumnConstants.idIp:
        return _buildCell(miner.ip, width, mono: true);
      case ColumnConstants.idStatus:
        return _buildStatusCell(context, miner.status, width);
      case ColumnConstants.idLocate:
        final isBlinking = blinkingIps.contains(miner.ip);
        return Container(
          width: width,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isBlinking,
              onChanged: (val) => onBlinkToggle(miner.ip, val),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case ColumnConstants.idMac:
        return _buildCell(miner.stats.macAddress ?? '-', width, mono: true);
      case ColumnConstants.idModel:
        return _buildCell(miner.model ?? '-', width);
      case ColumnConstants.idHashrateRt:
        return _buildCell('${miner.stats.hashrateRt.toStringAsFixed(2)} TH/s', width, mono: true, align: TextAlign.right);
      case ColumnConstants.idHashrateAvg:
        return _buildCell('${miner.stats.hashrateAvg.toStringAsFixed(2)} TH/s', width, mono: true, align: TextAlign.right);
      case ColumnConstants.idUptime:
        return _buildCell(_formatUptime(miner.stats.uptime), width, mono: true, align: TextAlign.right);
      
      // Meta info
      case ColumnConstants.idFirmware:
        return _buildCell(miner.stats.firmware ?? '-', width);
      case ColumnConstants.idSoftware:
        return _buildCell(miner.stats.software ?? '-', width);
      case ColumnConstants.idHardware:
        return _buildCell(miner.stats.hardware ?? '-', width);
        
      default:
        // Try to handle indexed fields
        if (colId.startsWith('temp_in_')) {
          final index = int.tryParse(colId.split('_').last) ?? 0;
          return _buildTempCell(miner.stats.tempInletMin, miner.stats.tempInletMax, index, width);
        }
        if (colId.startsWith('temp_out_')) {
          final index = int.tryParse(colId.split('_').last) ?? 0;
          return _buildTempCell(miner.stats.tempOutletMin, miner.stats.tempOutletMax, index, width);
        }
        if (colId.startsWith('fan_')) {
          final index = int.tryParse(colId.split('_').last) ?? 0;
          return _buildFanCell(miner.stats.fanSpeeds, index, width);
        }
        if (colId.startsWith('pool') || colId.startsWith('worker')) {
          return _buildPoolWorkerCell(context, miner.stats, colId, width);
        }
        
        return _buildCell('-', width);
    }
  }

  Widget _buildTempCell(List<double?> mins, List<double?> maxs, int index, double width) {
    if (index >= mins.length || index >= maxs.length) return _buildCell('-', width, align: TextAlign.right);
    return _buildCell(
      _formatTempRange(mins.elementAtOrNull(index), maxs.elementAtOrNull(index)),
      width,
      mono: true,
      align: TextAlign.right,
    );
  }

  Widget _buildFanCell(List<int?> fans, int index, double width) {
    if (index >= fans.length) return _buildCell('-', width, align: TextAlign.right);
    return _buildCell(
      _formatSingleFan(fans.elementAtOrNull(index)),
      width,
      mono: true,
      align: TextAlign.right,
    );
  }

  Widget _buildPoolWorkerCell(BuildContext context, MinerStats stats, String colId, double width) {
    switch (colId) {
      case ColumnConstants.idPool1: return _buildPoolCell(context, stats.pool1, width);
      case ColumnConstants.idWorker1: return _buildCell(stats.worker1 ?? '-', width);
      case ColumnConstants.idPool2: return _buildPoolCell(context, stats.pool2, width);
      case ColumnConstants.idWorker2: return _buildCell(stats.worker2 ?? '-', width);
      case ColumnConstants.idPool3: return _buildPoolCell(context, stats.pool3, width);
      case ColumnConstants.idWorker3: return _buildCell(stats.worker3 ?? '-', width);
      default: return _buildCell('-', width);
    }
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
            // Ensure no truncation for critical fields, allow wrapping for others if needed, 
            // but standard DataTable behavior is single line. 
            // For Fans, we widened column to Avoid truncation.
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
          SizedBox(width: 8),
          Container(
            height: 24,
            width: 1,
            color: context.border,
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.view_column, size: 18),
            onPressed: onShowColumnSettings,
            tooltip: 'Column Settings',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            style: IconButton.styleFrom(
              foregroundColor: context.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/services/credentials_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MinerListView extends StatefulWidget {
  final List<Miner> miners;
  final List<String> selectedIps;
  final Function(List<String>) onSelectionChanged;

  const MinerListView({
    super.key,
    required this.miners,
    required this.selectedIps,
    required this.onSelectionChanged,
  });

  @override
  State<MinerListView> createState() => _MinerListViewState();
}

class _MinerListViewState extends State<MinerListView> {
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Miner> get _sortedMiners {
    final miners = List<Miner>.from(widget.miners);
    
    if (_sortColumnIndex == null) return miners;

    miners.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumnIndex) {
        case 0: // Status
          comparison = a.status.index.compareTo(b.status.index);
          break;
        case 1: // IP Address
          comparison = a.ip.compareTo(b.ip);
          break;
        case 3: // Model
          comparison = (a.model ?? '').compareTo(b.model ?? '');
          break;
        case 4: // Hashrate RT
          comparison = a.stats.hashrateRt.compareTo(b.stats.hashrateRt);
          break;
        case 5: // Hashrate Avg
          comparison = a.stats.hashrateAvg.compareTo(b.stats.hashrateAvg);
          break;
        case 6: // Max Temp
          final aMaxTemp = _getMaxTemp(a.stats);
          final bMaxTemp = _getMaxTemp(b.stats);
          comparison = aMaxTemp.compareTo(bMaxTemp);
          break;
        case 8: // Uptime
          comparison = a.stats.uptime.compareTo(b.stats.uptime);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return miners;
  }

  double _getMaxTemp(MinerStats stats) {
    final allTemps = <double>[
      ...stats.temperatureChip,
      ...stats.temperaturePcb,
    ];
    return allTemps.isEmpty ? 0.0 : allTemps.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.miners.isEmpty) {
      return const Center(
        child: Text(
          'No miners found. Start a scan to discover miners.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final sortedMiners = _sortedMiners;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            showCheckboxColumn: true,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            columns: [
              DataColumn(
                label: const Text('Status'),
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              DataColumn(
                label: const Text('IP Address'),
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              const DataColumn(label: Text('MAC Address')),
              DataColumn(
                label: const Text('Model'),
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              DataColumn(
                label: const Text('Hashrate RT'),
                numeric: true,
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              DataColumn(
                label: const Text('Hashrate Avg'),
                numeric: true,
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              DataColumn(
                label: const Text('Max Temp'),
                numeric: true,
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              const DataColumn(label: Text('Fans')),
              DataColumn(
                label: const Text('Uptime'),
                numeric: true,
                onSort: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
              const DataColumn(label: Text('Pool 1')),
              const DataColumn(label: Text('Worker 1')),
              const DataColumn(label: Text('Pool 2')),
              const DataColumn(label: Text('Worker 2')),
              const DataColumn(label: Text('Pool 3')),
              const DataColumn(label: Text('Worker 3')),
              const DataColumn(label: Text('Firmware')),
              const DataColumn(label: Text('Software')),
              const DataColumn(label: Text('Hardware')),
            ],
            rows: sortedMiners.map((miner) {
              final isSelected = widget.selectedIps.contains(miner.ip);
              return DataRow(
                selected: isSelected,
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (miner.status == MinerStatus.dead) return Colors.red.withOpacity(0.15);
                  if (miner.status == MinerStatus.warning) return Colors.orange.withOpacity(0.1);
                  if (miner.status == MinerStatus.scanning) return Colors.blue.withOpacity(0.08);
                  return null; // Active - default
                }),
                onSelectChanged: (bool? selected) {
                  final newList = List<String>.from(widget.selectedIps);
                  if (selected == true) {
                    newList.add(miner.ip);
                  } else {
                    newList.remove(miner.ip);
                  }
                  widget.onSelectionChanged(newList);
                },
                onLongPress: () async {
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
                cells: [
                  DataCell(_buildStatusIcon(miner.status)),
                  DataCell(Text(miner.ip, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(miner.stats.macAddress ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(miner.model ?? 'Unknown')),
                  DataCell(Text('${miner.stats.hashrateRt.toStringAsFixed(2)} TH/s')),
                  DataCell(Text('${miner.stats.hashrateAvg.toStringAsFixed(2)} TH/s')),
                  DataCell(_buildTempText(miner.stats)),
                  DataCell(_buildFanSpeedsText(miner.stats.fanSpeeds)),
                  DataCell(_buildUptimeText(miner.stats.uptime)),
                  DataCell(_buildPoolText(miner.stats.pool1)),
                  DataCell(Text(miner.stats.worker1 ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(_buildPoolText(miner.stats.pool2)),
                  DataCell(Text(miner.stats.worker2 ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(_buildPoolText(miner.stats.pool3)),
                  DataCell(Text(miner.stats.worker3 ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(miner.stats.firmware ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(miner.stats.software ?? '--', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(miner.stats.hardware ?? '--', style: const TextStyle(fontSize: 12))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MinerStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MinerStatus.active:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case MinerStatus.warning:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case MinerStatus.dead:
        icon = Icons.error;
        color = Colors.red;
        break;
      case MinerStatus.scanning:
        icon = Icons.search;
        color = Colors.blue;
        break;
    }
    return Icon(icon, color: color);
  }

  Widget _buildTempText(MinerStats stats) {
    final allTemps = <double>[
      ...stats.temperatureChip,
      ...stats.temperaturePcb,
    ];
    
    if (allTemps.isEmpty) return const Text('--');

    final maxTemp = allTemps.reduce((a, b) => a > b ? a : b);
    
    Color color = Colors.green;
    if (maxTemp >= 85) color = Colors.red;
    else if (maxTemp >= 75) color = Colors.orange;

    return Text(
      maxTemp.toStringAsFixed(1),
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPoolText(String? poolUrl) {
    if (poolUrl == null || poolUrl.isEmpty) {
      return const Text('--', style: TextStyle(fontSize: 12));
    }
    
    // Extract pool name from URL (e.g., "stratum+tcp://ab.ss.greatpool.ca:3334" -> "greatpool.ca")
    try {
      final uri = Uri.parse(poolUrl.replaceFirst('stratum+tcp://', 'http://'));
      final host = uri.host;
      
      if (host.isEmpty) {
        return const Text('--', style: TextStyle(fontSize: 12));
      }
      
      final parts = host.split('.');
      if (parts.length >= 2) {
        final domain = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
        return Text(domain, style: const TextStyle(fontSize: 12));
      }
      return Text(host, style: const TextStyle(fontSize: 12));
    } catch (e) {
      // Fallback: show truncated URL
      final maxLen = poolUrl.length > 20 ? 20 : poolUrl.length;
      return Text(
        poolUrl.substring(0, maxLen),
        style: const TextStyle(fontSize: 12),
      );
    }
  }

  Widget _buildFanSpeedsText(Uint32List fans) {
    if (fans.isEmpty) return const Text('--', style: TextStyle(fontSize: 12));
    
    return Text(
      '${fans.join(' | ')}',
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildUptimeText(BigInt uptime) {
    final seconds = uptime.toInt();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    return Text(
      '${hours}h ${minutes}m',
      style: const TextStyle(fontSize: 12),
    );
  }
}

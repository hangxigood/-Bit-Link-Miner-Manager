
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/src/models/data_column_config.dart';
import 'package:frontend/src/constants/column_constants.dart';

class ColumnService {
  static const String _prefsKey = 'miner_table_columns_v5';

  Future<List<DataColumnConfig>> loadColumnSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up old preference keys if needed, or leave them be. 
      // The original code did cleanup, so we can keep it if we want, or just focus on v5.
      // For cleaner service, I'll stick to loading/saving v5.

      final String? jsonStr = prefs.getString(_prefsKey);

      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        return jsonList.map((e) => DataColumnConfig(
          id: e['id'],
          label: e['label'],
          visible: e['visible'],
          width: (e['width'] as num?)?.toDouble() ?? 100.0,
        )).toList();
      }
    } catch (e) {
      // Return default on error
    }
    return _getDefaultColumns();
  }

  Future<void> saveColumnSettings(List<DataColumnConfig> columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = columns.map((c) => {
        'id': c.id,
        'label': c.label,
        'visible': c.visible,
        'width': c.width,
      }).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
    } catch (e) {
      // Handle or log error
    }
  }

  List<DataColumnConfig> _getDefaultColumns() {
    return [
      DataColumnConfig(id: ColumnConstants.idIp, label: 'IP Address', visible: true, width: ColumnConstants.widthIp),
      DataColumnConfig(id: ColumnConstants.idStatus, label: 'Status', visible: true, width: ColumnConstants.widthStatus),
      DataColumnConfig(id: ColumnConstants.idLocate, label: 'Locate', visible: true, width: ColumnConstants.widthLocate),
      DataColumnConfig(id: ColumnConstants.idModel, label: 'Model', visible: true, width: ColumnConstants.widthModel),
      DataColumnConfig(id: ColumnConstants.idHashrateRt, label: 'Hashrate', visible: true, width: ColumnConstants.widthHashrate),
      DataColumnConfig(id: ColumnConstants.idHashrateAvg, label: 'Avg Hash', visible: false, width: ColumnConstants.widthHashrate),
      DataColumnConfig(id: ColumnConstants.idTempIn0, label: 'InT-0', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idTempIn1, label: 'InT-1', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idTempIn2, label: 'InT-2', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idTempOut0, label: 'OutT-0', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idTempOut1, label: 'OutT-1', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idTempOut2, label: 'OutT-2', visible: true, width: ColumnConstants.widthTemp),
      DataColumnConfig(id: ColumnConstants.idFan0, label: 'Fan-0', visible: true, width: ColumnConstants.widthFan),
      DataColumnConfig(id: ColumnConstants.idFan1, label: 'Fan-1', visible: true, width: ColumnConstants.widthFan),
      DataColumnConfig(id: ColumnConstants.idFan2, label: 'Fan-2', visible: true, width: ColumnConstants.widthFan),
      DataColumnConfig(id: ColumnConstants.idFan3, label: 'Fan-3', visible: true, width: ColumnConstants.widthFan),
      DataColumnConfig(id: ColumnConstants.idUptime, label: 'Uptime', visible: true, width: ColumnConstants.widthUptime),
      DataColumnConfig(id: ColumnConstants.idPool1, label: 'Pool 1', visible: true, width: ColumnConstants.widthPool),
      DataColumnConfig(id: ColumnConstants.idWorker1, label: 'Worker 1', visible: true, width: ColumnConstants.widthWorker),
      DataColumnConfig(id: ColumnConstants.idPool2, label: 'Pool 2', visible: false, width: ColumnConstants.widthPool),
      DataColumnConfig(id: ColumnConstants.idWorker2, label: 'Worker 2', visible: false, width: ColumnConstants.widthWorker),
      DataColumnConfig(id: ColumnConstants.idPool3, label: 'Pool 3', visible: false, width: ColumnConstants.widthPool),
      DataColumnConfig(id: ColumnConstants.idWorker3, label: 'Worker 3', visible: false, width: ColumnConstants.widthWorker),
      DataColumnConfig(id: ColumnConstants.idMac, label: 'MAC Addr', visible: false, width: ColumnConstants.widthMac),
      DataColumnConfig(id: ColumnConstants.idFirmware, label: 'Firmware', visible: false, width: ColumnConstants.widthMeta),
      DataColumnConfig(id: ColumnConstants.idSoftware, label: 'Software', visible: false, width: ColumnConstants.widthMeta),
      DataColumnConfig(id: ColumnConstants.idHardware, label: 'Hardware', visible: false, width: ColumnConstants.widthMeta),
    ];
  }

  // Create reset method to be used by controller
  List<DataColumnConfig> getDefaultColumns() => _getDefaultColumns();
}

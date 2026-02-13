class ColumnConstants {
  // Column IDs
  static const String idIp = 'ip';
  static const String idStatus = 'status';
  static const String idLocate = 'locate';
  static const String idModel = 'model';
  static const String idHashrateRt = 'hashrate_rt';
  static const String idHashrateAvg = 'hashrate_avg';
  static const String idTempIn0 = 'temp_in_0';
  static const String idTempIn1 = 'temp_in_1';
  static const String idTempIn2 = 'temp_in_2';
  static const String idTempOut0 = 'temp_out_0';
  static const String idTempOut1 = 'temp_out_1';
  static const String idTempOut2 = 'temp_out_2';
  static const String idFan0 = 'fan_0';
  static const String idFan1 = 'fan_1';
  static const String idFan2 = 'fan_2';
  static const String idFan3 = 'fan_3';
  static const String idUptime = 'uptime';
  static const String idPool1 = 'pool1';
  static const String idWorker1 = 'worker1';
  static const String idPool2 = 'pool2';
  static const String idWorker2 = 'worker2';
  static const String idPool3 = 'pool3';
  static const String idWorker3 = 'worker3';
  static const String idMac = 'mac';
  static const String idFirmware = 'firmware';
  static const String idSoftware = 'software';
  static const String idHardware = 'hardware';

  // Default Widths
  static const double widthIp = 130.0;
  static const double widthStatus = 110.0;
  static const double widthLocate = 90.0;
  static const double widthModel = 100.0;
  static const double widthHashrate = 100.0;
  static const double widthTemp = 100.0;
  static const double widthFan = 80.0;
  static const double widthUptime = 120.0;
  static const double widthPool = 180.0;
  static const double widthWorker = 150.0;
  static const double widthMac = 140.0;
  static const double widthMeta = 110.0;
  static const double widthDefault = 100.0;

  static double getDefaultWidth(String id) {
    switch (id) {
      case idIp: return widthIp;
      case idStatus: return widthStatus;
      case idLocate: return widthLocate;
      case idModel: return widthModel;
      case idHashrateRt:
      case idHashrateAvg: return widthHashrate;
      case idTempIn0:
      case idTempIn1:
      case idTempIn2:
      case idTempOut0:
      case idTempOut1:
      case idTempOut2: return widthTemp;
      case idFan0:
      case idFan1:
      case idFan2:
      case idFan3: return widthFan;
      case idUptime: return widthUptime;
      case idPool1:
      case idPool2:
      case idPool3: return widthPool;
      case idWorker1:
      case idWorker2:
      case idWorker3: return widthWorker;
      case idMac: return widthMac;
      case idFirmware:
      case idSoftware:
      case idHardware: return widthMeta;
      default: return widthDefault;
    }
  }
}

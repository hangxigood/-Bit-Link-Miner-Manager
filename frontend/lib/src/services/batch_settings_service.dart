import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting staggered batch execution settings.
class BatchSettingsService {
  static const String _batchSizeKey = 'batch_size';
  static const String _batchDelayKey = 'batch_delay_seconds';

  static const int defaultBatchSize = 10;
  static const int defaultBatchDelay = 10;

  /// Get stored batch size or default
  static Future<int> getBatchSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_batchSizeKey) ?? defaultBatchSize;
  }

  /// Get stored batch delay (seconds) or default
  static Future<int> getBatchDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_batchDelayKey) ?? defaultBatchDelay;
  }

  /// Save batch size
  static Future<void> setBatchSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batchSizeKey, size.clamp(1, 50));
  }

  /// Save batch delay (seconds)
  static Future<void> setBatchDelay(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batchDelayKey, seconds.clamp(1, 60));
  }
}

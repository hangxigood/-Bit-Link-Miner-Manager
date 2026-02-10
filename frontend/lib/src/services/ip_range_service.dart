import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing saved IP scan ranges
class IpRangeService {
  static const String _key = 'saved_ip_ranges';
  static const String _defaultRange = '192.168.1.1-192.168.1.254';

  /// Get all saved ranges (or default if none saved)
  static Future<List<String>> getSavedRanges() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [_defaultRange];
    final List<dynamic> decoded = jsonDecode(json);
    final ranges = decoded.cast<String>();
    return ranges.isEmpty ? [_defaultRange] : ranges;
  }

  /// Add a range (deduplicates)
  static Future<void> addRange(String range) async {
    final trimmed = range.trim();
    if (trimmed.isEmpty) return;
    final ranges = await getSavedRanges();
    if (ranges.contains(trimmed)) return;
    ranges.add(trimmed);
    await _save(ranges);
  }

  /// Remove a range
  static Future<void> removeRange(String range) async {
    final ranges = await getSavedRanges();
    ranges.remove(range);
    await _save(ranges);
  }

  /// Clear all saved ranges
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<String> ranges) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ranges));
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing miner credentials
class CredentialsService {
  static const String _usernameKey = 'miner_username';
  static const String _passwordKey = 'miner_password';
  
  static const String defaultUsername = 'root';
  static const String defaultPassword = 'root';

  /// Get stored username or default
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey) ?? defaultUsername;
  }

  /// Get stored password or default
  static Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey) ?? defaultPassword;
  }

  /// Save username
  static Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  /// Save password
  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, password);
  }

  /// Reset to defaults
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }
}

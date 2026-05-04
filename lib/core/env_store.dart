import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores the selected environment identifier string using
/// [SharedPreferences].
///
/// The stored value is the raw `.name` of the user's enum — it is the
/// caller's responsibility to convert back to the enum value.
class EnvStore {
  static const String _key = 'envify_selected_env';

  /// Persists [value] (the enum's `.name`) to [SharedPreferences].
  Future<void> save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  /// Restores the previously saved env name, or `null` if nothing is saved.
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Clears the persisted selection.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

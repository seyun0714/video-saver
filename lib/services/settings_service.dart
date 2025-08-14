// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  List<String> _whitelist = ['example.org'];
  bool _wifiOnly = false;

  List<String> get whitelist => _whitelist;
  bool get wifiOnly => _wifiOnly;

  Future<void> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    _whitelist = sp.getStringList('whitelist') ?? ['example.org'];
    _wifiOnly = sp.getBool('wifiOnly') ?? false;
  }

  Future<void> saveSettings({
    required List<String> newWhitelist,
    required bool newWifiOnly,
  }) async {
    _whitelist = newWhitelist;
    _wifiOnly = newWifiOnly;
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('whitelist', _whitelist);
    await sp.setBool('wifiOnly', _wifiOnly);
  }

  bool isAllowedDomain(String host) {
    return _whitelist.any(
      (w) => host == w.toLowerCase() || host.endsWith('.${w.toLowerCase()}'),
    );
  }
}

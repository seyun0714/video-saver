// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // --- 👇 [수정] whitelist 관련 코드 삭제 ---
  // List<String> _whitelist = ['example.org'];
  bool _wifiOnly = false;

  // List<String> get whitelist => _whitelist;
  bool get wifiOnly => _wifiOnly;

  Future<void> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    // _whitelist = sp.getStringList('whitelist') ?? ['example.org'];
    _wifiOnly = sp.getBool('wifiOnly') ?? false;
  }

  Future<void> saveSettings({required bool newWifiOnly}) async {
    // _whitelist = newWhitelist;
    _wifiOnly = newWifiOnly;
    final sp = await SharedPreferences.getInstance();
    // await sp.setStringList('whitelist', _whitelist);
    await sp.setBool('wifiOnly', _wifiOnly);
  }
}

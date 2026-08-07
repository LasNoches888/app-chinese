import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Holds the configurable backend base URL and exposes an [ApiClient]
/// built from it. Default targets the Android emulator's host loopback;
/// override in-app for a physical device or iOS simulator.
class AppSettings extends ChangeNotifier {
  static const _baseUrlKey = 'base_url';
  static const defaultBaseUrl = 'http://10.0.2.2:8000';
  static const _userId = 'demo-user';

  String _baseUrl = defaultBaseUrl;
  String get baseUrl => _baseUrl;
  String get userId => _userId;

  ApiClient get client => ApiClient(baseUrl: _baseUrl, userId: _userId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
}

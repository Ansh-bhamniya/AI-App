import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_settings.dart';

/// Holds the current [AssistantSettings] and persists every change.
class SettingsController extends ChangeNotifier {
  static const _key = 'assistant_settings_v1';
  static const _apiKeyKey = 'anthropic_api_key';

  AssistantSettings _settings = const AssistantSettings();
  AssistantSettings get settings => _settings;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final apiKey = prefs.getString(_apiKeyKey) ?? '';
      if (raw != null) {
        _settings = AssistantSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
          apiKey: apiKey,
        );
      } else {
        _settings = _settings.copyWith(apiKey: apiKey);
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AssistantSettings Function(AssistantSettings s) change) async {
    final next = change(_settings);
    final apiKeyChanged = next.apiKey != _settings.apiKey;
    _settings = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(next.toJson()));
      if (apiKeyChanged) await prefs.setString(_apiKeyKey, next.apiKey);
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }

  Future<void> reset() => update((s) => AssistantSettings(apiKey: s.apiKey));
}

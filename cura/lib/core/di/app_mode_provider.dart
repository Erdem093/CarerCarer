import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { user, carer }

const _kAppModeKey = 'app_mode';
const _kCarerPinKey = 'carer_pin';

final appModeProvider = StateNotifierProvider<AppModeNotifier, AppMode>(
  (ref) => AppModeNotifier(),
);

class AppModeNotifier extends StateNotifier<AppMode> {
  AppModeNotifier() : super(AppMode.user) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kAppModeKey);
    if (value == 'carer') state = AppMode.carer;
  }

  Future<void> setMode(AppMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppModeKey, mode.name);
  }

  Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCarerPinKey);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCarerPinKey, pin);
  }
}

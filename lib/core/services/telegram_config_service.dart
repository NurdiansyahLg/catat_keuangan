import 'package:shared_preferences/shared_preferences.dart';

class TelegramConfigService {
  TelegramConfigService._internal();
  static final TelegramConfigService instance = TelegramConfigService._internal();

  static const String _keyBotToken = 'telegram_bot_token';
  static const String _keyChatId = 'telegram_chat_id';
  static const String _keyAutoSync = 'telegram_auto_sync';
  static const String _keyLastSync = 'telegram_last_sync';
  static const String _keyLastStatus = 'telegram_last_status';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String get botToken => _prefs?.getString(_keyBotToken) ?? '';
  String get chatId => _prefs?.getString(_keyChatId) ?? '';
  bool get autoSync => _prefs?.getBool(_keyAutoSync) ?? true;
  String? get lastSyncIso => _prefs?.getString(_keyLastSync);
  String get lastStatus => _prefs?.getString(_keyLastStatus) ?? 'Belum Terkonfigurasi';

  DateTime? get lastSyncTime {
    final iso = lastSyncIso;
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  bool get isConfigured => botToken.trim().isNotEmpty && chatId.trim().isNotEmpty;

  Future<void> saveConfig({
    required String botToken,
    required String chatId,
    required bool autoSync,
  }) async {
    await init();
    await _prefs?.setString(_keyBotToken, botToken.trim());
    await _prefs?.setString(_keyChatId, chatId.trim());
    await _prefs?.setBool(_keyAutoSync, autoSync);
  }

  Future<void> setAutoSync(bool value) async {
    await init();
    await _prefs?.setBool(_keyAutoSync, value);
  }

  Future<void> updateSyncStatus({
    required String status,
    DateTime? syncTime,
  }) async {
    await init();
    await _prefs?.setString(_keyLastStatus, status);
    if (syncTime != null) {
      await _prefs?.setString(_keyLastSync, syncTime.toIso8601String());
    }
  }

  Future<void> clearConfig() async {
    await init();
    await _prefs?.remove(_keyBotToken);
    await _prefs?.remove(_keyChatId);
    await _prefs?.remove(_keyAutoSync);
    await _prefs?.remove(_keyLastSync);
    await _prefs?.remove(_keyLastStatus);
  }
}

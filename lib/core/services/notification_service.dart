import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'catat_keuangan_reminder';
  static const _channelName = 'Pengingat Keuangan';
  static const _notifId = 1;
  static const _prefHour = 'notif_hour';
  static const _prefMin = 'notif_min';
  static const _prefEnabled = 'notif_enabled';

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    // v21+: initialize uses named parameter
    await _plugin.initialize(settings: settings);
  }

  /// Jadwalkan notifikasi harian jam [hour]:[minute]
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    // v21+: cancel uses named parameter
    await _plugin.cancel(id: _notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // v21+: zonedSchedule uses named parameters
    await _plugin.zonedSchedule(
      id: _notifId,
      title: '💰 Catat Keuangan Hari Ini',
      body: 'Jangan lupa catat pengeluaran dan pemasukan hari ini!',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Simpan preferensi
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, hour);
    await prefs.setInt(_prefMin, minute);
  }

  Future<void> cancelReminder() async {
    // v21+: cancel uses named parameter
    await _plugin.cancel(id: _notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
  }

  Future<(bool enabled, TimeOfDay time)> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    final hour = prefs.getInt(_prefHour) ?? 20;
    final min = prefs.getInt(_prefMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    return granted;
  }
}

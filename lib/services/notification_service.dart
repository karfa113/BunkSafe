import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily 6 PM reminder if no attendance is marked for today.
/// Re-armed from AppState whenever attendance changes (or the app boots).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _reminderId = 1001;
  static const int _reminderHour = 18; // 6 PM
  static const int _reminderMinute = 0;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initFuture;
  bool _supported = false;

  bool get _platformSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() {
    // Single-flight: all callers await the same in-flight future so a fast
    // second call doesn't race past initialization and silently no-op.
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    if (!_platformSupported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fall back to UTC if device timezone lookup fails.
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      await _requestPermissions();
      _supported = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService init failed: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        await android.requestNotificationsPermission();
      } catch (_) {}
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      try {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}
    }
  }

  /// Schedules (or refreshes) the 6 PM reminder for today.
  /// If [hasMarkForToday] is true, any pending reminder is cancelled.
  /// If 6 PM has already passed, no reminder is scheduled.
  Future<void> rescheduleTodayReminder({required bool hasMarkForToday}) async {
    await init();
    if (!_supported) return;

    try {
      await _plugin.cancel(_reminderId);
    } catch (_) {}
    if (hasMarkForToday) return;

    final now = tz.TZDateTime.now(tz.local);
    final fireTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _reminderHour,
      _reminderMinute,
    );
    if (!fireTime.isAfter(now)) return; // 6 PM has already passed today

    const androidDetails = AndroidNotificationDetails(
      'bunksafe_daily_reminder',
      'Attendance reminder',
      channelDescription:
          'Reminds you to mark today\'s attendance if it\'s still empty at 6 PM.',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Attendance reminder',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        _reminderId,
        'BunkSafe',
        'You haven\'t marked today\'s attendance yet. Tap to update.',
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule attendance reminder: $e');
      }
    }
  }

  Future<void> cancelTodayReminder() async {
    if (_initFuture == null || !_supported) return;
    try {
      await _plugin.cancel(_reminderId);
    } catch (_) {}
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Local reminders. Scheduled on-device only: one nudge 3 days before a job
/// is due and one on the day, both at 9 in the morning. Exact alarms are
/// requested so OEM battery saving does not silently swallow them; if the
/// user declines, the in-app Today screen still carries everything.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _ready = true;
  }

  static Future<void> requestPermissions() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static tz.TZDateTime _atNineLocal(DateTime date) {
    final offset = DateTime.now().timeZoneOffset;
    final utc = DateTime.utc(date.year, date.month, date.day, 9).subtract(offset);
    return tz.TZDateTime.from(utc, tz.UTC);
  }

  /// Replace all scheduled reminders with the current plan's next 30 jobs.
  static Future<void> reschedule(List<TaskInstance> tasks) async {
    await init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final upcoming = tasks
        .where((t) => t.status == TaskStatus.upcoming && t.id != null)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'nestkeep_reminders',
        'Maintenance reminders',
        channelDescription: 'Reminders before home maintenance jobs are due',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    var scheduled = 0;
    for (final t in upcoming) {
      if (scheduled >= 30) break;
      final slots = <(DateTime, String)>[
        (
          t.dueDate.subtract(const Duration(days: 3)),
          '${t.title} is due in 3 days'
        ),
        (t.dueDate, '${t.title} is due today'),
      ];
      for (var i = 0; i < slots.length; i++) {
        final when = _atNineLocal(slots[i].$1);
        if (when.isBefore(tz.TZDateTime.now(tz.UTC))) continue;
        await _plugin.zonedSchedule(
          t.id! * 2 + i,
          'NestKeep',
          slots[i].$2,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
      scheduled++;
    }
    // Keep "now" referenced so lints stay quiet about the unused local in
    // release builds where the loop body changes.
    assert(now.millisecondsSinceEpoch > 0);
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Local reminders. Scheduled on-device only: one nudge 3 days before a job
/// is due and one on the day, both at 9 in the morning. Scheduling is
/// inexact on purpose: these are day-level nudges, so the app never asks
/// for the exact-alarm permission, whose request throws the user out of
/// the app into system Settings. If notifications are declined, the
/// in-app Today screen still carries everything.
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
  }

  static tz.TZDateTime _atNineLocal(DateTime date) {
    final offset = DateTime.now().timeZoneOffset;
    final utc = DateTime.utc(date.year, date.month, date.day, 9).subtract(offset);
    return tz.TZDateTime.from(utc, tz.UTC);
  }

  /// The warranty warnings for one appliance: 30 days before the warranty
  /// runs out, and on the day it ends. Only future dates are returned, and
  /// an appliance with no purchase date gets none. Pure date math so it
  /// can be tested.
  static List<(DateTime, String)> warrantySlots(Appliance a, DateTime now) {
    final purchase = a.purchaseDate;
    if (purchase == null) return const [];
    final expiry = DateTime(
      purchase.year,
      purchase.month + a.warrantyMonths,
      purchase.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return [
      (
        expiry.subtract(const Duration(days: 30)),
        'The warranty on ${a.name} ends in 30 days'
      ),
      (expiry, 'The warranty on ${a.name} ends today'),
    ].where((s) => !s.$1.isBefore(today)).toList();
  }

  /// Replace all scheduled reminders with the current plan's next 30 jobs,
  /// plus a 30-day warning before each appliance warranty runs out.
  static Future<void> reschedule(List<TaskInstance> tasks,
      [List<Appliance> appliances = const []]) async {
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      scheduled++;
    }
    for (final a in appliances) {
      if (a.id == null) continue;
      final slots = warrantySlots(a, now);
      for (var i = 0; i < slots.length; i++) {
        final when = _atNineLocal(slots[i].$1);
        if (when.isBefore(tz.TZDateTime.now(tz.UTC))) continue;
        await _plugin.zonedSchedule(
          1000000 + a.id! * 2 + i,
          'NestKeep',
          slots[i].$2,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
    // Keep "now" referenced so lints stay quiet about the unused local in
    // release builds where the loop body changes.
    assert(now.millisecondsSinceEpoch > 0);
  }
}

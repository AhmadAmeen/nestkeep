import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'models.dart';

/// Calendar support, the honest one-way kind. No calendar permission,
/// no plugin, and this app never reads or writes anyone's calendar:
///  - addJobToCalendar opens the user's calendar app with one job
///    prefilled as an all-day event; the user presses save there.
///  - sharePlanIcs exports every upcoming job as an .ics file the user
///    can import wherever they like.
const _channel = MethodChannel('nestkeep/calendar');

Future<bool> addJobToCalendar({
  required String title,
  required DateTime dueDate,
  required String description,
}) async {
  // All-day events are anchored at midnight UTC.
  final begin = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
  final end = begin.add(const Duration(days: 1));
  try {
    final ok = await _channel.invokeMethod<bool>('insertEvent', {
      'title': title,
      'description': description,
      'beginMillis': begin.millisecondsSinceEpoch,
      'endMillis': end.millisecondsSinceEpoch,
    });
    return ok ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

String _icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

String _icsDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _icsStamp(DateTime now) {
  final u = now.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${_icsDate(u)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

String jobDescription(TaskInstance t, TaskTemplate? tpl) {
  if (tpl == null) return 'A NestKeep job for your home.';
  final steps = [
    for (var i = 0; i < tpl.steps.length; i++) '${i + 1}. ${tpl.steps[i]}'
  ].join('\n');
  return '${tpl.why}\n\nHow to do it:\n$steps';
}

/// The whole plan as one .ics document: every upcoming job becomes an
/// all-day event on its due date. Pure function, unit-tested.
String buildIcs(
  List<TaskInstance> upcoming,
  Map<String, TaskTemplate> templates,
  DateTime now,
) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NestKeep//Plan//EN',
    'CALSCALE:GREGORIAN',
  ];
  for (final t in upcoming) {
    final tpl = t.templateId == null ? null : templates[t.templateId];
    final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:nestkeep-task-${t.id ?? '${t.templateId}-${_icsDate(due)}'}@nestkeep',
      'DTSTAMP:${_icsStamp(now)}',
      'DTSTART;VALUE=DATE:${_icsDate(due)}',
      'DTEND;VALUE=DATE:${_icsDate(due.add(const Duration(days: 1)))}',
      'SUMMARY:${_icsEscape(t.title)}',
      'DESCRIPTION:${_icsEscape(jobDescription(t, tpl))}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return lines.join('\r\n');
}

Future<void> sharePlanIcs(AppState state) async {
  final ics = buildIcs(state.upcoming, state.templateById, DateTime.now());
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/nestkeep-plan.ics');
  await file.writeAsString(ics);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

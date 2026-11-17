import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/calendar.dart';
import 'package:nestkeep/models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 9, 30, 0);
  TaskTemplate tpl() => TaskTemplate(
        id: 'hvac-filter',
        category: 'HVAC',
        title: 'Change the HVAC air filter',
        frequencyMonths: 3,
        seasons: const [],
        diyCost: 20,
        ignoreCost: 300,
        difficulty: 'Easy',
        minutes: 10,
        why: 'A clogged filter costs energy.',
        steps: const ['Turn it off.', 'Swap the filter.'],
        needs: const ['Filter'],
      );
  TaskInstance task(DateTime due, {String title = 'Change the HVAC air filter'}) =>
      TaskInstance(
        id: 7,
        homeId: 1,
        templateId: 'hvac-filter',
        title: title,
        category: 'HVAC',
        dueDate: due,
        updatedAt: now,
      );

  test('ics has one all-day event per upcoming job', () {
    final ics = buildIcs([task(DateTime(2026, 12, 1))], {'hvac-filter': tpl()}, now);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('DTSTART;VALUE=DATE:20261201'));
    expect(ics, contains('DTEND;VALUE=DATE:20261202'));
    expect(ics, contains('SUMMARY:Change the HVAC air filter'));
    expect(ics, contains('A clogged filter costs energy.'));
    expect(ics, contains('END:VCALENDAR'));
  });

  test('ics escapes commas, semicolons and newlines', () {
    final ics = buildIcs(
      [task(DateTime(2026, 12, 1), title: 'Clean gutters, roof; check flashing')],
      {'hvac-filter': tpl()},
      now,
    );
    expect(ics, contains('SUMMARY:Clean gutters\\, roof\\; check flashing'));
    // Field newlines are escaped, so lines split cleanly on CRLF.
    expect(ics, contains('How to do it:\\n1. Turn it off.'));
    for (final line in ics.split('\r\n')) {
      expect(line.contains('\n'), isFalse);
    }
  });

  test('empty plan still produces a valid calendar shell', () {
    final ics = buildIcs(const [], const {}, now);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, isNot(contains('VEVENT')));
  });
}

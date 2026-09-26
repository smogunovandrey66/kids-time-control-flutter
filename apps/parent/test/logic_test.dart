import 'package:flutter_test/flutter_test.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_parent/logic/child_form.dart';
import 'package:ktc_parent/logic/stats.dart';

import 'fakes.dart';

void main() {
  group('stats', () {
    final usage = [
      const DailyUsage(
        childId: 'ivan',
        date: '2026-09-28',
        totalSeconds: 1800,
        apps: {'minecraft': 1200, 'roblox': 600},
      ),
      const DailyUsage(childId: 'ivan', date: '2026-09-26', totalSeconds: 7200),
      const DailyUsage(childId: 'marina', date: '2026-09-28', totalSeconds: 60),
    ];

    test('today summary uses the weekday limit plus bonus', () {
      final child = testChild(
        bonus: const Bonus(date: '2026-09-28', seconds: 900),
      );

      final summary = todaySummary(child, usage, now);

      expect(summary.used, const Duration(minutes: 30));
      expect(summary.limit, const Duration(minutes: 75));
      expect(summary.remaining, const Duration(minutes: 45));
      expect(summary.apps.first.key, 'minecraft');
    });

    test('week has 7 days, oldest first, zeros for missing days', () {
      final week = weekFor('ivan', usage, now);

      expect(week, hasLength(7));
      expect(week.first.day, DateTime(2026, 9, 22));
      expect(week.last.seconds, 1800);
      expect(week[4].seconds, 7200);
      expect(week[5].seconds, 0);
    });

    test('bonus adds up on the same day and resets on another day', () {
      final once = withBonus(testChild(), const Duration(minutes: 15), now);
      final twice = withBonus(once, const Duration(minutes: 30), now);
      final nextDay = withBonus(
        twice,
        const Duration(minutes: 15),
        DateTime(2026, 9, 29),
      );

      expect(twice.bonus!.seconds, 45 * 60);
      expect(nextDay.bonus!.date, '2026-09-29');
      expect(nextDay.bonus!.seconds, 15 * 60);
    });

    test('formatHoursMinutes', () {
      expect(formatHoursMinutes(const Duration(minutes: 65)), '1:05');
    });
  });

  group('child form', () {
    List<ChildFormError> validate({
      String name = 'Ivan',
      String pin = '1234',
      bool isNew = true,
      String weekday = '60',
    }) => validateChild(
      name: name,
      pin: pin,
      isNew: isNew,
      weekdayMinutes: weekday,
      weekendMinutes: '120',
    );

    test('accepts a valid child', () => expect(validate(), isEmpty));
    test(
      'requires a name',
      () => expect(validate(name: '  '), [ChildFormError.nameEmpty]),
    );
    test('requires a PIN for a new child only', () {
      expect(validate(pin: ''), [ChildFormError.pinRequired]);
      expect(validate(pin: '', isNew: false), isEmpty);
    });
    test('PIN is 4-6 digits', () {
      expect(validate(pin: '12'), [ChildFormError.pinInvalid]);
      expect(validate(pin: '12a4'), [ChildFormError.pinInvalid]);
      expect(validate(pin: '123456'), isEmpty);
    });
    test('limit is 0-1440 minutes', () {
      expect(validate(weekday: '1441'), [ChildFormError.limitInvalid]);
      expect(validate(weekday: 'x'), [ChildFormError.limitInvalid]);
    });
    test('the real hash verifies', () async {
      final hash = await hashPinInBackground('4321', iterations: 1000);
      expect(verifyPin('4321', hash), isTrue);
    });
  });
}

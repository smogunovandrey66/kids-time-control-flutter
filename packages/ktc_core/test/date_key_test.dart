import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  test('dateKey pads month and day', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('bonus applies only to its day', () {
    const child = Child(
      id: 'ivan',
      name: 'Ivan',
      pinHash: 'x',
      limits: Limits(weekdaySeconds: 3600, weekendSeconds: 3600),
      bonus: Bonus(date: '2026-09-28', seconds: 1800),
    );

    expect(
      child.limitFor(DateTime(2026, 9, 28, 18)),
      const Duration(minutes: 90),
    );
    expect(child.limitFor(DateTime(2026, 9, 29)), const Duration(minutes: 60));
  });
}

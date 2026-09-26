import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ktc_core/ktc_core.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../logic/stats.dart';
import 'widgets.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final usage = ref.watch(weekUsageProvider).value ?? const <DailyUsage>[];
    final apps = {
      for (final app in ref.watch(appsProvider).value ?? <AppRule>[])
        app.id: app.name,
    };
    final now = ref.watch(clockProvider)();

    return switch (children) {
      AsyncData(value: final list) when list.isEmpty => EmptyHint(
        context.l10n.todayNoChildren,
      ),
      AsyncData(value: final list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final child in list)
            _ChildTodayCard(
              child: child,
              summary: todaySummary(child, usage, now),
              week: weekFor(child.id, usage, now),
              appNames: apps,
            ),
        ],
      ),
      AsyncError(:final error) => EmptyHint(
        context.l10n.errorGeneric('$error'),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _ChildTodayCard extends ConsumerWidget {
  const _ChildTodayCard({
    required this.child,
    required this.summary,
    required this.week,
    required this.appNames,
  });

  final Child child;
  final TodaySummary summary;
  final List<({DateTime day, int seconds})> week;
  final Map<String, String> appNames;

  Future<void> _addTime(
    BuildContext context,
    WidgetRef ref,
    int minutes,
  ) async {
    final family = ref.read(familyProvider).value;
    if (family == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await runWithErrorSnack(context, () async {
      final updated = withBonus(
        child,
        Duration(minutes: minutes),
        ref.read(clockProvider)(),
      );
      await ref.read(familyRepositoryProvider).saveChild(family.id, updated);
      messenger.showSnackBar(SnackBar(content: Text(l10n.bonusAdded)));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(child.name, style: theme.textTheme.titleLarge),
                ),
                Text(
                  l10n.usedOfLimit(
                    formatHoursMinutes(summary.used),
                    formatHoursMinutes(summary.limit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: summary.progress),
            const SizedBox(height: 8),
            Text(l10n.remaining(formatHoursMinutes(summary.remaining))),
            for (final MapEntry(key: appId, value: seconds)
                in summary.apps.take(3))
              Text(
                '${appNames[appId] ?? appId}: ${formatHoursMinutes(Duration(seconds: seconds))}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Text(l10n.weekTitle, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            WeekBars(week: week, limit: child.limitFor(DateTime.now())),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in const [15, 30, 60])
                  OutlinedButton(
                    onPressed: () => _addTime(context, ref, minutes),
                    child: Text(l10n.addMinutes(minutes)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal bar chart of the last 7 days; the dashed level is the daily limit.
class WeekBars extends StatelessWidget {
  const WeekBars({required this.week, required this.limit, super.key});

  final List<({DateTime day, int seconds})> week;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxSeconds = [
      limit.inSeconds,
      for (final day in week) day.seconds,
    ].reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    const height = 64.0;
    return SizedBox(
      height: height + 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in week)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height * day.seconds / maxSeconds,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: day.seconds > limit.inSeconds
                          ? colors.error
                          : colors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    '${day.day.day}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

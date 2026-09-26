import 'dart:convert';

import 'models.dart';

/// Local configuration of the PC (`config.json`): children and controlled games.
///
/// Stage 1 edits it by hand; in stage 2 it becomes a cache of the Firestore data.
/// Schema: `shared/schema/config.schema.json`.
final class LocalConfig {
  const LocalConfig({required this.children, required this.apps});

  factory LocalConfig.fromJson(Map<String, Object?> json) {
    final children = json['children']! as Map<String, Object?>;
    final apps = json['apps']! as Map<String, Object?>;
    return LocalConfig(
      children: [
        for (final MapEntry(:key, :value) in children.entries)
          Child.fromJson(key, value! as Map<String, Object?>),
      ],
      apps: [
        for (final MapEntry(:key, :value) in apps.entries)
          AppRule.fromJson(key, value! as Map<String, Object?>),
      ],
    );
  }

  factory LocalConfig.parse(String source) =>
      LocalConfig.fromJson(jsonDecode(source) as Map<String, Object?>);

  final List<Child> children;
  final List<AppRule> apps;

  Map<String, Object?> toJson() => {
    'children': {for (final child in children) child.id: child.toJson()},
    'apps': {for (final app in apps) app.id: app.toJson()},
  };

  /// Active (not archived) child with [id], or `null`.
  Child? child(String id) {
    for (final child in children) {
      if (child.id == id && !child.archived) return child;
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ktc_core/ktc_core.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets.dart';

void openAppEditor(BuildContext context, [AppRule? app]) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => AppEditPage(app: app)));

String describeMatch(AppRule app) => [
  ?app.exeName,
  ?app.exePath,
  if (app.commandLineContains case final text? when text.isNotEmpty) '"$text"',
].where((part) => part.isNotEmpty).join(' · ');

class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(appsProvider)) {
      AsyncData(value: final list) when list.isEmpty => EmptyHint(
        l10n.gamesEmpty,
      ),
      AsyncData(value: final list) => ListView(
        children: [
          for (final app in list)
            ListTile(
              leading: const Icon(Icons.sports_esports),
              title: Text(app.name),
              subtitle: Text(describeMatch(app)),
              onTap: () => openAppEditor(context, app),
            ),
        ],
      ),
      AsyncError(:final error) => EmptyHint(l10n.errorGeneric('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class AppEditPage extends ConsumerStatefulWidget {
  const AppEditPage({this.app, super.key});

  final AppRule? app;

  @override
  ConsumerState<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends ConsumerState<AppEditPage> {
  late final _name = TextEditingController(text: widget.app?.name);
  late final _exeName = TextEditingController(text: widget.app?.exeName);
  late final _exePath = TextEditingController(text: widget.app?.exePath);
  late final _commandLine = TextEditingController(
    text: widget.app?.commandLineContains,
  );
  String? _nameError;
  String? _criteriaError;

  @override
  void dispose() {
    for (final controller in [_name, _exeName, _exePath, _commandLine]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _valueOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final exeName = _valueOrNull(_exeName);
    final exePath = _valueOrNull(_exePath);
    final commandLine = _valueOrNull(_commandLine);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l10n.errorNameEmpty : null;
      _criteriaError = exeName == null && exePath == null && commandLine == null
          ? l10n.errorNoCriteria
          : null;
    });
    if (_nameError != null || _criteriaError != null) return;

    final family = ref.read(familyProvider).value!;
    final repository = ref.read(familyRepositoryProvider);
    final navigator = Navigator.of(context);
    await runWithErrorSnack(context, () async {
      await repository.saveApp(
        family.id,
        AppRule(
          id: widget.app?.id ?? repository.newId(),
          name: _name.text.trim(),
          exeName: exeName,
          exePath: exePath,
          commandLineContains: commandLine,
        ),
      );
      navigator.pop();
    });
  }

  Future<void> _archive() async {
    final app = widget.app!;
    final family = ref.read(familyProvider).value!;
    final navigator = Navigator.of(context);
    await runWithErrorSnack(context, () async {
      await ref
          .read(familyRepositoryProvider)
          .saveApp(
            family.id,
            AppRule(
              id: app.id,
              name: app.name,
              exeName: app.exeName,
              exePath: app.exePath,
              commandLineContains: app.commandLineContains,
              archived: true,
            ),
          );
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app == null ? l10n.addGame : l10n.editGame),
        actions: [
          if (widget.app != null)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete),
              onPressed: _archive,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.gameName,
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.matchHint, style: Theme.of(context).textTheme.bodySmall),
          if (_criteriaError != null)
            Text(
              _criteriaError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextField(
            controller: _exeName,
            decoration: InputDecoration(labelText: l10n.exeName),
          ),
          TextField(
            controller: _exePath,
            decoration: InputDecoration(labelText: l10n.exePath),
          ),
          TextField(
            controller: _commandLine,
            decoration: InputDecoration(labelText: l10n.commandLineContains),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

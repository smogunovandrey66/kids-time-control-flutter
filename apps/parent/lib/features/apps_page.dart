import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ktc_core/ktc_core.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../logic/programs.dart';
import '../logic/stats.dart';
import 'widgets.dart';

void openAppEditor(BuildContext context, [AppRule? app]) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => AppEditPage(app: app)));

void openProgramPicker(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ProgramPickerPage()));

String describeMatch(AppRule app) => [
  ?app.exeName,
  ?app.exePath,
  if (app.folder case final folder?) '$folder\\…',
  if (app.commandLineContains case final text? when text.isNotEmpty) '"$text"',
].where((part) => part.isNotEmpty).join(' · ');

class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pick = ListTile(
      leading: const Icon(Icons.manage_search),
      title: Text(l10n.pickFromPc),
      subtitle: Text(l10n.pickFromPcHint),
      onTap: () => openProgramPicker(context),
    );
    return switch (ref.watch(appsProvider)) {
      AsyncData(value: final list) when list.isEmpty => ListView(
        children: [
          pick,
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.gamesEmpty, textAlign: TextAlign.center),
          ),
        ],
      ),
      AsyncData(value: final list) => ListView(
        children: [
          pick,
          const Divider(),
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
  const AppEditPage({this.app, this.suggestion, this.seenPath, super.key});

  /// The rule being edited; `null` for a new one.
  final AppRule? app;

  /// Initial values for a new rule (from a program seen on the PC).
  final AppRule? suggestion;

  /// Where that program was found, shown to help fill in the folder.
  final String? seenPath;

  @override
  ConsumerState<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends ConsumerState<AppEditPage> {
  late final _initial = widget.app ?? widget.suggestion;
  late final _name = TextEditingController(text: _initial?.name);
  late final _exeName = TextEditingController(text: _initial?.exeName);
  late final _exePath = TextEditingController(text: _initial?.exePath);
  late final _commandLine = TextEditingController(
    text: _initial?.commandLineContains,
  );
  late final _folder = TextEditingController(text: _initial?.folder);
  String? _nameError;
  String? _criteriaError;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _exeName,
      _exePath,
      _commandLine,
      _folder,
    ]) {
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
    final folder = _valueOrNull(_folder);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l10n.errorNameEmpty : null;
      _criteriaError =
          exeName == null &&
              exePath == null &&
              commandLine == null &&
              folder == null
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
          folder: folder,
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
              folder: app.folder,
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
          if (widget.seenPath case final path?) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(l10n.foundOnPc(path)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(
                      l10n.fillExeName(
                        path.substring(path.lastIndexOf('\\') + 1),
                      ),
                    ),
                    onPressed: () => setState(() {
                      _exeName.text = path.substring(
                        path.lastIndexOf('\\') + 1,
                      );
                    }),
                  ),
                  ActionChip(
                    label: Text(l10n.fillExePath),
                    onPressed: () => setState(() => _exePath.text = path),
                  ),
                  if (path.contains('\\'))
                    Builder(
                      builder: (context) {
                        final folder = path.substring(
                          0,
                          path.lastIndexOf('\\'),
                        );
                        return ActionChip(
                          label: Text(l10n.fillFolder(folder)),
                          onPressed: () =>
                              setState(() => _folder.text = folder),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
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
          TextField(
            controller: _folder,
            decoration: InputDecoration(
              labelText: l10n.gameFolder,
              helperText: l10n.gameFolderHint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

class ProgramPickerPage extends ConsumerWidget {
  const ProgramPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(devicesProvider).value ?? const [];
    final apps = ref.watch(appsProvider).value ?? const [];
    final candidates = programCandidates(devices, apps);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickFromPc)),
      body: candidates.isEmpty
          ? EmptyHint(l10n.programsEmpty)
          : ListView(
              children: [
                for (final candidate in candidates)
                  _ProgramTile(candidate: candidate),
              ],
            ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.candidate});

  final ProgramCandidate candidate;

  /// `2026-09-26` → `26.09`: the catalog covers about two weeks.
  static String _shortDay(String lastSeen) {
    final parts = lastSeen.split('-');
    if (parts.length != 3) return lastSeen;
    return '${parts[2]}.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final program = candidate.program;
    final matched = candidate.matchedBy;
    final suggestion = program.suggestRule('');
    return ListTile(
      leading: Icon(
        matched == null ? Icons.add_circle_outline : Icons.check_circle,
        color: matched == null ? null : Theme.of(context).colorScheme.primary,
      ),
      title: Text(suggestion.name),
      subtitle: Text(
        [
          if (matched != null) l10n.alreadyGame(matched.name),
          l10n.programUsage(
            formatHoursMinutes(Duration(seconds: program.seconds)),
            candidate.deviceNames.join(', '),
          ),
          l10n.lastRun(_shortDay(program.lastSeen)),
          program.exePath,
        ].join('\n'),
      ),
      isThreeLine: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => matched != null
              ? AppEditPage(app: matched, seenPath: program.exePath)
              : AppEditPage(suggestion: suggestion, seenPath: program.exePath),
        ),
      ),
    );
  }
}

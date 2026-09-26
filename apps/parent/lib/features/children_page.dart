import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ktc_core/ktc_core.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../logic/child_form.dart';
import 'widgets.dart';

void openChildEditor(BuildContext context, [Child? child]) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => ChildEditPage(child: child)));

class ChildrenPage extends ConsumerWidget {
  const ChildrenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(childrenProvider)) {
      AsyncData(value: final list) when list.isEmpty => EmptyHint(
        l10n.childrenEmpty,
      ),
      AsyncData(value: final list) => ListView(
        children: [
          for (final child in list)
            ListTile(
              leading: CircleAvatar(
                child: Text(child.name.characters.first.toUpperCase()),
              ),
              title: Text(child.name),
              subtitle: Text(
                '${l10n.weekdayLimit}: ${child.limits.weekdaySeconds ~/ 60} · '
                '${l10n.weekendLimit}: ${child.limits.weekendSeconds ~/ 60}',
              ),
              onTap: () => openChildEditor(context, child),
            ),
        ],
      ),
      AsyncError(:final error) => EmptyHint(l10n.errorGeneric('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class ChildEditPage extends ConsumerStatefulWidget {
  const ChildEditPage({this.child, super.key});

  /// `null` creates a new child.
  final Child? child;

  @override
  ConsumerState<ChildEditPage> createState() => _ChildEditPageState();
}

class _ChildEditPageState extends ConsumerState<ChildEditPage> {
  late final _name = TextEditingController(text: widget.child?.name);
  final _pin = TextEditingController();
  late final _weekday = TextEditingController(
    text: '${(widget.child?.limits.weekdaySeconds ?? 3600) ~/ 60}',
  );
  late final _weekend = TextEditingController(
    text: '${(widget.child?.limits.weekendSeconds ?? 7200) ~/ 60}',
  );
  var _errors = <ChildFormError>[];
  var _saving = false;

  bool get _isNew => widget.child == null;

  @override
  void dispose() {
    for (final controller in [_name, _pin, _weekday, _weekend]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final errors = validateChild(
      name: _name.text,
      pin: _pin.text,
      isNew: _isNew,
      weekdayMinutes: _weekday.text,
      weekendMinutes: _weekend.text,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final family = ref.read(familyProvider).value!;
    final repository = ref.read(familyRepositoryProvider);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await runWithErrorSnack(context, () async {
      final pinHash = _pin.text.isEmpty
          ? widget.child!.pinHash
          : await ref.read(pinHasherProvider)(_pin.text);
      final limits = Limits(
        weekdaySeconds: int.parse(_weekday.text) * 60,
        weekendSeconds: int.parse(_weekend.text) * 60,
      );
      final child = Child(
        id: widget.child?.id ?? repository.newId(),
        name: _name.text.trim(),
        pinHash: pinHash,
        limits: limits,
        bonus: widget.child?.bonus,
      );
      await repository.saveChild(family.id, child);
      navigator.pop();
    });
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _archive() async {
    final family = ref.read(familyProvider).value!;
    final navigator = Navigator.of(context);
    await runWithErrorSnack(context, () async {
      await ref
          .read(familyRepositoryProvider)
          .saveChild(family.id, widget.child!.copyWith(archived: true));
      navigator.pop();
    });
  }

  String? _error(List<ChildFormError> kinds) {
    final l10n = context.l10n;
    for (final error in _errors) {
      if (!kinds.contains(error)) continue;
      return switch (error) {
        ChildFormError.nameEmpty => l10n.errorNameEmpty,
        ChildFormError.nameTooLong => l10n.errorNameTooLong,
        ChildFormError.pinInvalid => l10n.errorPinInvalid,
        ChildFormError.pinRequired => l10n.errorPinRequired,
        ChildFormError.limitInvalid => l10n.errorLimitInvalid,
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addChild : l10n.editChild),
        actions: [
          if (!_isNew)
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
              labelText: l10n.childName,
              errorText: _error(const [
                ChildFormError.nameEmpty,
                ChildFormError.nameTooLong,
              ]),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            decoration: InputDecoration(
              labelText: l10n.pin,
              helperText: _isNew ? l10n.pinHintNew : l10n.pinHintKeep,
              errorText: _error(const [
                ChildFormError.pinInvalid,
                ChildFormError.pinRequired,
              ]),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
          ),
          TextField(
            controller: _weekday,
            decoration: InputDecoration(
              labelText: l10n.weekdayLimit,
              errorText: _error(const [ChildFormError.limitInvalid]),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weekend,
            decoration: InputDecoration(labelText: l10n.weekendLimit),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

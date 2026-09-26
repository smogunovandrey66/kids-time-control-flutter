import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets.dart';

/// IANA time zone of the phone; days in the statistics are local to it.
final timeZoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

class CreateFamilyPage extends ConsumerStatefulWidget {
  const CreateFamilyPage({super.key});

  @override
  ConsumerState<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends ConsumerState<CreateFamilyPage> {
  final _name = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await runWithErrorSnack(context, () async {
      final timeZone = await ref.read(timeZoneProvider.future);
      await ref
          .read(familyRepositoryProvider)
          .createFamily(
            parentUid: user.uid,
            name: _name.text.trim(),
            timeZone: timeZone,
          );
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createFamilyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.createFamilyDescription),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.familyName),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _create,
            child: Text(l10n.createFamily),
          ),
        ],
      ),
    );
  }
}

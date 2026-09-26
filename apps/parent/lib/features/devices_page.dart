import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ktc_core/ktc_core.dart';

import '../data/providers.dart';
import '../data/repositories.dart';
import '../l10n/l10n.dart';
import 'widgets.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toString();
    return switch (ref.watch(devicesProvider)) {
      AsyncData(value: final list) when list.isEmpty => EmptyHint(
        l10n.computersEmpty,
      ),
      AsyncData(value: final list) => ListView(
        children: [
          for (final device in list)
            if (device.userIsAdmin ?? false)
              Card(
                margin: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(l10n.adminWarningTitle),
                  subtitle: Text(l10n.adminWarning(device.name)),
                ),
              ),
          for (final device in list)
            ListTile(
              leading: Icon(
                Icons.computer,
                color: device.isOnline(now)
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(device.name),
              subtitle: Text(
                device.lastSeen == null
                    ? l10n.neverSeen
                    : device.isOnline(now)
                    ? l10n.online
                    : l10n.lastSeen(
                        DateFormat.MMMd(
                          locale,
                        ).add_Hm().format(device.lastSeen!.toLocal()),
                      ),
              ),
              trailing: PopupMenuButton<void>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () => _remove(context, ref, device),
                    child: Text(l10n.removeComputer),
                  ),
                ],
              ),
            ),
        ],
      ),
      AsyncError(:final error) => EmptyHint(l10n.errorGeneric('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final family = ref.read(familyProvider).value!;
    await runWithErrorSnack(
      context,
      () => ref.read(familyRepositoryProvider).removeDevice(family, device.id),
    );
  }
}

Future<void> showPairDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const PairDialog());

class PairDialog extends ConsumerStatefulWidget {
  const PairDialog({super.key});

  @override
  ConsumerState<PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends ConsumerState<PairDialog> {
  final _code = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final l10n = context.l10n;
    final code = PairingCode.normalize(_code.text);
    if (code == null) {
      setState(() => _error = l10n.pairingInvalid);
      return;
    }
    final family = ref.read(familyProvider).value!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(familyRepositoryProvider)
          .pairDevice(family, code);
      if (result == PairingResult.paired) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(l10n.paired)));
      } else {
        setState(() => _error = l10n.pairingNotFound);
      }
    } on Exception catch (error) {
      setState(() => _error = l10n.errorGeneric('$error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pairComputer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pairingHint),
          const SizedBox(height: 12),
          TextField(
            key: const Key('pairingCode'),
            controller: _code,
            decoration: InputDecoration(
              labelText: l10n.pairingCodeLabel,
              hintText: 'ABCD-2345',
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _pair, child: Text(l10n.pair)),
      ],
    );
  }
}

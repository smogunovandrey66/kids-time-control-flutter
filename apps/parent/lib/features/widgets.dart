import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.errorGeneric('$error'),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Centered hint for empty lists.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

/// Shows a snack bar with the error of a failed write.
Future<void> runWithErrorSnack(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await action();
  } on Exception catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.errorGeneric('$error'))),
    );
  }
}

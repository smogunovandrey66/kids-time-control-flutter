import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sports_esports, size: 72),
              const SizedBox(height: 24),
              Text(
                l10n.signInTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(l10n.signInDescription, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: Text(l10n.signInWithGoogle),
                onPressed: () => runWithErrorSnack(
                  context,
                  () => ref.read(authRepositoryProvider).signInWithGoogle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

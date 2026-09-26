import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'features/create_family_page.dart';
import 'features/home_shell.dart';
import 'features/sign_in_page.dart';
import 'features/widgets.dart';
import 'l10n/l10n.dart';

ThemeData buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B6D2F),
    brightness: brightness,
  ),
);

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appTitle,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AuthGate(),
  );
}

/// Sign-in → family creation → home, driven by the auth and family streams.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    return switch (user) {
      AsyncData(value: null) => const SignInPage(),
      AsyncData() => const _FamilyGate(),
      AsyncError(:final error) => ErrorView(error: error),
      _ => const LoadingView(),
    };
  }
}

class _FamilyGate extends ConsumerWidget {
  const _FamilyGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    return switch (family) {
      AsyncData(value: null) => const CreateFamilyPage(),
      AsyncData() => const HomeShell(),
      AsyncError(:final error) => ErrorView(error: error),
      _ => const LoadingView(),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/firebase_repositories.dart';
import 'data/providers.dart';
import 'features/setup_required_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `flutterfire configure` replaces the placeholder; until then explain what to do.
  if (DefaultFirebaseOptions.currentPlatform.apiKey == 'placeholder') {
    runApp(const SetupRequiredApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FirebaseAuthRepository(FirebaseAuth.instance),
        ),
        familyRepositoryProvider.overrideWithValue(
          FirestoreFamilyRepository(FirebaseFirestore.instance),
        ),
      ],
      child: const ParentApp(),
    ),
  );
}

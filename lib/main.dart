import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'adapters/storage/rename_migration.dart';
import 'app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app used to be called Sleepytime, and on Windows the name decides
  // where the data lives — the support directory is built from the
  // executable's ProductName. Renaming without this would point a family at
  // an empty folder: no stories, no narration, no saved keys. Runs before
  // anything is opened, copies rather than moves, and never overwrites.
  await carryOverFromOldName(await windowsRenamePaths());

  // Resolve the configured story + voice providers BEFORE the first frame.
  // These read from prefs + secure storage asynchronously; if we let the UI
  // start first, the opening story/narration races them and silently falls back
  // to the offline placeholder + robotic device voice. Warming a shared
  // container here guarantees Gemini (etc.) is active from the very first tap.
  final container = ProviderContainer();
  await Future.wait([
    container.read(aiConfigProvider.notifier).refresh(),
    container.read(voiceConfigProvider.notifier).refresh(),
  ]);

  runApp(
    UncontrolledProviderScope(container: container, child: const MoonloomApp()),
  );
}

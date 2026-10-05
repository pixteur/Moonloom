/// Which story provider does the app *actually* end up with on this machine?
///
/// Run as a Flutter entrypoint, not with `dart run`, because the question is
/// what the real Windows plugins return — the real shared_preferences file and
/// the real DPAPI secret store — and a unit test replaces both with mocks:
///
///     flutter run -d windows -t tool/ai_resolve_probe.dart
///
/// Written after a story came back as six identical canned chapters with every
/// setting apparently right, twice. The first explanation (a race) was real
/// but was not the cause; this prints each step of the decision instead of
/// guessing at it, then exits.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/prefs/app_prefs.dart';
import 'package:moonloom/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final out = <String>[];
  void say(String s) {
    out.add(s);
    // ignore: avoid_print
    print('PROBE $s');
  }

  try {
    final prefs = await AppPrefs.open();
    say('consent           ${prefs.aiConsentGiven}');
    say('selected provider ${prefs.selectedProvider}');

    final container = ProviderContainer();
    final secrets = container.read(secretStoreProvider);
    say('has gemini key    ${await secrets.hasKey(GeminiProvider.keyName)}');
    final key = await secrets.readKey(GeminiProvider.keyName);
    say(
      'key decrypts      ${key != null && key.isNotEmpty}'
      '${key == null ? '' : ' (${key.length} chars)'}',
    );

    say('config at once    ${container.read(aiConfigProvider)}');
    await container.read(aiConfigProvider.notifier).ready;
    say('config when ready ${container.read(aiConfigProvider)}');
    say('text model        "${container.read(textModelProvider)}"');
    say('ai provider       ${container.read(aiProvider).runtimeType}');
    say('engine ai         ${container.read(storyEngineProvider).runtimeType}');
  } catch (e, st) {
    say('THREW $e\n$st');
  }

  File(
    '${Platform.environment['TEMP']}\\ai_resolve_probe.txt',
  ).writeAsStringSync(out.join('\n'));
  exit(0);
}

/// Ask a Gemini model for one real chapter, through the app's own provider.
///
/// Changing the default model is a guess until something has actually written
/// a story with it. The list endpoint says a model exists; it does not say the
/// request body we send is still accepted — `thinkingBudget: 0` was tuned for
/// gemini-2.5-flash, and a newer model refusing it would surface as every
/// story falling back, not as an obvious error. So this sends the real prompt
/// shape and prints what comes back.
///
///     dart run tool/gemini_smoke.dart                 # the app's default
///     dart run tool/gemini_smoke.dart gemini-3.8-flash gemini-3.1-pro-preview
///
/// Costs one short generation per model named. Writes nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sleepytime/adapters/ai/gemini_provider.dart';
import 'package:sleepytime/adapters/secrets/dpapi.dart';
import 'package:sleepytime/adapters/secrets/secret_store.dart';
import 'package:sleepytime/domain/models/beat.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/models/story_request.dart';
import 'package:sleepytime/domain/prompt_builder.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\sleepytime\shared_preferences.json',
    );
    if (!file.existsSync()) throw StateError('No prefs at ${file.path}');
    return _StoredKeys(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> _prefs;

  @override
  Future<String?> readKey(String providerId) async {
    final stored = _prefs['flutter.enckey_$providerId'] as String?;
    if (stored == null) return null;
    try {
      return dpapiUnprotect(base64.decode(stored));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasKey(String providerId) async =>
      _prefs['flutter.enckey_$providerId'] != null;

  @override
  Future<void> writeKey(String providerId, String key) async =>
      throw UnsupportedError('read-only probe');

  @override
  Future<void> deleteKey(String providerId) async =>
      throw UnsupportedError('read-only probe');
}

Future<void> main(List<String> args) async {
  final models = args.isEmpty ? [GeminiProvider.defaultModel] : args;
  final secrets = await _StoredKeys.open();
  final client = http.Client();

  // Built through the real PromptBuilder, with the exact situation that was
  // reported broken: a hero the grown-up named, in a world whose inherited
  // cast contains the character the model kept using instead.
  final prompt = const PromptBuilder().build(
    StoryRequest(
      child: const ChildProfile(id: 'c1', displayName: 'Mia', age: 6),
      series: const Series(
        id: 's1',
        childId: 'c1',
        title: 'Mystical Creature',
        theme: StoryTheme.cozy,
        seedSummary: 'A child who likes quiet puzzles and gentle mysteries.',
        heroMode: HeroMode.namedHero,
        heroName: 'Crystal',
      ),
      intent: StoryIntent.dice,
      chosenTwist: 'a lantern that will not go out',
      worldPremise: 'A hush-lit forest where small creatures trade riddles.',
      cast: const ['Pip — a small brave fox who leads the way'],
    ),
  );

  for (final model in models) {
    stdout.write('${model.padRight(34)} ');
    final started = DateTime.now();
    try {
      final segment = await GeminiProvider(
        secrets: secrets,
        httpClient: client,
        model: model,
      ).generate(prompt);
      final ms = DateTime.now().difference(started).inMilliseconds;
      final words = segment.storyText.split(RegExp(r'\s+')).length;
      final named = segment.storyText.contains('Crystal');
      final ghost = segment.storyText.contains('Pip');
      stdout.writeln(
        'ok  ${ms}ms  $words words  '
        'hero=$named  pip-still-leading=$ghost  "${segment.chapterTitle}"',
      );
      stdout.writeln('   ${segment.storyText.split('\n').first}');
    } catch (e) {
      stdout.writeln('FAILED');
      stdout.writeln('   $e');
    }
  }
  client.close();
}

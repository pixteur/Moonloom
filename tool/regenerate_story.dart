/// Write a story again, from the settings of one that already exists.
///
/// **This one costs money and changes the library.** Every other script in
/// `tool/` is a read-only probe; this calls the story provider and saves what
/// comes back, so it is a dry run unless `--write` is given, and it never
/// touches the story it copies from — it makes a new one beside it.
///
///     dart run tool/regenerate_story.dart --series <id>
///     dart run tool/regenerate_story.dart --series <id> --write
///     dart run tool/regenerate_story.dart --series <id> --write --title "..."
///
/// Existed because a bilingual story came out in one language: the drafting
/// pass wrote it correctly and the editorial pass translated it away. Once
/// that was fixed the only way to see the fix was to write the story again
/// with the same settings, which is what this does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/ai/ai_provider.dart';
import 'package:moonloom/adapters/ai/claude_provider.dart';
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/ai/openai_provider.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/story_engine.dart';
import 'package:moonloom/domain/twist_deck.dart';

/// The app's own key store, read straight off disk. SharedPreferences needs
/// Flutter bindings a `dart run` script does not have, but the file it writes
/// is plain JSON and the blob inside it is ordinary DPAPI.
class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\moonloom\shared_preferences.json',
    );
    return _StoredKeys(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> _prefs;

  String? pref(String key) => _prefs['flutter.$key'] as String?;

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
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;

  @override
  Future<void> writeKey(String providerId, String key) async =>
      throw UnsupportedError('read-only');

  @override
  Future<void> deleteKey(String providerId) async =>
      throw UnsupportedError('read-only');
}

Future<void> main(List<String> args) async {
  final sourceId = _option(args, '--series');
  final live = args.contains('--write');
  if (sourceId == null) {
    stderr.writeln('--series <id> is required');
    exitCode = 2;
    return;
  }

  final documents = '${Platform.environment['USERPROFILE']}\\Documents';
  final db = AppDatabase.openIn(documents);
  final repo = DriftStorageRepo(db);

  final source = await repo.loadSeriesById(sourceId);
  if (source == null) {
    stderr.writeln('No series $sourceId');
    exitCode = 1;
    await db.close();
    return;
  }
  final child = await repo.loadProfile(source.childId);
  if (child == null) {
    stderr.writeln('No child ${source.childId}');
    exitCode = 1;
    await db.close();
    return;
  }

  final keys = await _StoredKeys.open();
  final providerName = keys.pref('selected_provider') ?? 'claude';
  final model = keys.pref('textmodel_$providerName') ?? '';
  final ai = _providerFor(providerName, keys, model);
  final language = languageFor(source, child.language);

  stdout
    ..writeln('Source   "${source.title}"  (${source.id})')
    ..writeln('Child    ${child.displayName}, ${child.age}')
    ..writeln('World    ${source.worldId ?? "standalone"}')
    ..writeln('Themes   ${source.allThemes.map((t) => t.name).join(", ")}')
    ..writeln('Hero     ${source.heroMode.name} ${source.heroName ?? ""}')
    ..writeln(
      'Language $language'
      '${source.bilingualEnabled ? " + ${source.secondaryLanguage} "
                "(${source.bilingualBlend?.name})" : ""}',
    )
    ..writeln('Provider $providerName ${model.isEmpty ? "(default)" : model}');

  if (!live) {
    stdout.writeln(
      '\nDRY RUN — nothing written and no request sent. '
      'Add --write to generate.',
    );
    await db.close();
    return;
  }

  final series = await SeriesService(repo).create(
    childId: source.childId,
    title: _option(args, '--title') ?? source.title,
    theme: source.theme,
    extraThemes: source.extraThemes,
    worldId: source.worldId,
    customTheme: source.customTheme,
    heroMode: source.heroMode,
    heroName: source.heroName,
    seedSummary: source.seedSummary,
    baseLanguage: source.baseLanguage,
    bilingualEnabled: source.bilingualEnabled,
    secondaryLanguage: source.secondaryLanguage,
    bilingualBlend: source.bilingualBlend,
  );
  stdout.writeln('\nNew story ${series.id}');

  // The same loop the chapter screen runs: opening twist first, then continue
  // until the model calls an end or the cap is reached.
  final engine = StoryEngine(ai: ai, repo: repo);
  const maxChapters = 6;
  for (var i = 0; i < maxChapters; i++) {
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: i == 0 ? StoryIntent.dice : StoryIntent.continued,
      chosenTwist: i == 0 ? const TwistDeck().roll().hint : null,
    );
    final reason = engine.lastFallbackReason;
    stdout.writeln(
      '  ${i + 1}. ${beat.title.isEmpty ? "(untitled)" : beat.title}  '
      '${beat.text.length} chars'
      '${reason == null ? "" : "  [placeholder: $reason]"}',
    );
    if (beat.isFinal) break;
  }

  await db.close();
  stdout.writeln('\nDone. Open it in the app to read or narrate it.');
  exit(0);
}

AiProvider _providerFor(String name, SecretStore secrets, String model) =>
    switch (name) {
      'openai' => OpenAiProvider(
        secrets: secrets,
        model: model.isEmpty ? OpenAiProvider.defaultModel : model,
      ),
      'gemini' => GeminiProvider(
        secrets: secrets,
        model: model.isEmpty ? GeminiProvider.defaultModel : model,
      ),
      _ => ClaudeProvider(
        secrets: secrets,
        model: model.isEmpty ? ClaudeProvider.defaultModel : model,
      ),
    };

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i == -1 || i + 1 >= args.length ? null : args[i + 1];
}

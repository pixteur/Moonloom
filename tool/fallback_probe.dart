/// Read-only: why does a new episode come back as canned chapters?
///
/// The engine never lets a model failure reach the screen. Every exception in
/// the generate loop is caught, turned into a sentence in `lastFallbackReason`,
/// and replaced with a generic fallback chapter — which is right for a child at
/// bedtime and terrible for diagnosis, because the symptom is "a story called
/// Naming it… with identical generic chapters" and the cause is gone.
///
/// The model itself answering is not enough to rule the engine out: the
/// engine sends the real prompt, with the world's real cast, through the real
/// editorial pass. So this runs one real turn, against the real child and the
/// real world, and prints what the engine caught.
///
/// Nothing is written to the library. The child, world and cast are copied
/// into an in-memory store first, so the series the turn creates and the
/// chapter it saves vanish when this exits.
///
///     dart run tool/fallback_probe.dart --child Mia --world "Pip's Adventures"
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/story_engine.dart';

import '../test/support/in_memory_storage_repo.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

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
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;
  @override
  Future<void> writeKey(String id, String key) async =>
      throw UnsupportedError('read-only');
  @override
  Future<void> deleteKey(String id) async =>
      throw UnsupportedError('read-only');
}

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

Future<void> main(List<String> args) async {
  final childName = _opt(args, '--child') ?? 'Mia';
  final worldName = _opt(args, '--world');

  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final model = (prefs['flutter.textmodel_gemini'] as String?) ?? '';

  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE']}\\Documents',
  );
  final real = DriftStorageRepo(db);

  final child = (await real.loadProfiles()).cast<ChildProfile?>().firstWhere(
    (c) => c!.displayName.toLowerCase() == childName.toLowerCase(),
    orElse: () => null,
  );
  if (child == null) {
    stdout.writeln('No child called $childName.');
    await db.close();
    return;
  }
  final worlds = await real.loadWorlds(child.id);
  final world = worldName == null
      ? worlds.first
      : worlds.firstWhere(
          (w) => w.name.toLowerCase() == worldName.toLowerCase(),
          orElse: () => worlds.first,
        );
  final cast = await real.loadCharacters(world.id);
  await db.close();

  // A private copy, so the turn below writes nowhere that matters.
  final repo = InMemoryStorageRepo();
  await repo.saveProfile(child);
  await repo.saveWorld(world);
  for (final c in cast) {
    await repo.saveCharacter(c);
  }

  stdout.writeln('child: ${child.displayName}   world: ${world.name}');
  stdout.writeln('cast:  ${cast.map((c) => c.promptLine).join(' | ')}');
  stdout.writeln(
    'model: ${model.isEmpty ? '(the provider default)' : model}\n',
  );

  final client = http.Client();
  final engine = StoryEngine(
    ai: GeminiProvider(
      secrets: _StoredKeys(prefs),
      httpClient: client,
      model: model.isEmpty ? GeminiProvider.defaultModel : model,
    ),
    repo: repo,
  );
  final series = await SeriesService(repo).create(
    childId: child.id,
    title: 'Naming it…',
    theme: world.theme,
    autoTitle: true,
    worldId: world.id,
    detailLevel: child.detailLevel,
  );

  final beat = await engine.takeTurn(
    child: child,
    series: series,
    intent: StoryIntent.dice,
  );

  final reason = engine.lastFallbackReason;
  stdout.writeln(
    reason == null
        ? 'REAL CHAPTER — no fallback.'
        : 'FELL BACK. The engine caught:\n\n  $reason',
  );
  stdout.writeln(
    '\ntitle now: ${(await repo.loadSeriesById(series.id))?.title}',
  );
  stdout.writeln('chapter:   ${beat.title}');
  stdout.writeln(
    '           ${beat.text.substring(0, beat.text.length.clamp(0, 240))}…',
  );
  client.close();
}

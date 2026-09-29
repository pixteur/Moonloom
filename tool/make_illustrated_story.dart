/// Write a real story into the library and illustrate it.
///
/// This exists because the app cannot be driven from here, and the pictures
/// need to be judged in the place a child would see them — on the chapter
/// list and above the words — not as loose PNGs on a desktop.
///
///     dart run tool/make_illustrated_story.dart --child Mia --world "Pip's Adventures" --length short
///     dart run tool/make_illustrated_story.dart --child Mia --world "Pip's Adventures" --length long
///
/// Writes to the real library: a new series, its chapters, and its pictures.
/// Dry run by default; `--write` means it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sleepytime/adapters/ai/gemini_provider.dart';
import 'package:sleepytime/adapters/images/picture_store.dart';
import 'package:sleepytime/adapters/images/story_illustrator.dart';
import 'package:sleepytime/adapters/secrets/dpapi.dart';
import 'package:sleepytime/adapters/secrets/secret_store.dart';
import 'package:sleepytime/adapters/storage/app_database.dart';
import 'package:sleepytime/adapters/storage/drift_storage_repo.dart';
import 'package:sleepytime/domain/illustration_service.dart';
import 'package:sleepytime/domain/models/beat.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/series_service.dart';
import 'package:sleepytime/domain/story_engine.dart';
import 'package:uuid/uuid.dart';

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
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;
  @override
  Future<void> writeKey(String id, String key) async =>
      throw UnsupportedError('read-only');
  @override
  Future<void> deleteKey(String id) async =>
      throw UnsupportedError('read-only');
}

String? _opt(List<String> args, String name) {
  final at = args.indexOf(name);
  return at >= 0 && at + 1 < args.length ? args[at + 1] : null;
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final childName = _opt(args, '--child') ?? 'Mia';
  final worldName = _opt(args, '--world');
  final length = _opt(args, '--length') ?? 'short';
  final detail = switch (length) {
    'short' => DetailLevel.short,
    'medium' => DetailLevel.medium,
    _ => DetailLevel.long,
  };

  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE']}\\Documents',
  );
  final repo = DriftStorageRepo(db);
  final secrets = await _StoredKeys.open();
  final client = http.Client();

  // Find the child and the world by name, so this reads like the request did.
  final children = await repo.loadProfiles();
  final child = children.cast<ChildProfile?>().firstWhere(
    (c) => c!.displayName.toLowerCase() == childName.toLowerCase(),
    orElse: () => null,
  );
  if (child == null) {
    stdout.writeln('No child called $childName.');
    await db.close();
    return;
  }
  final worlds = await repo.loadWorlds(child.id);
  if (worlds.isEmpty) {
    stdout.writeln('$childName has no worlds.');
    await db.close();
    return;
  }
  final world = worldName == null
      ? worlds.first
      : worlds.firstWhere(
          (w) => w.name.toLowerCase() == worldName.toLowerCase(),
          orElse: () => worlds.first,
        );
  final cast = (await repo.loadCharacters(
    world.id,
  )).map((c) => c.promptLine).toList();

  stdout.writeln('child:  ${child.displayName} (${child.age})');
  stdout.writeln('world:  ${world.name}');
  stdout.writeln('cast:   ${cast.isEmpty ? '(none saved)' : cast.join('; ')}');
  stdout.writeln('length: $length');
  if (!write) {
    stdout.writeln('\nDry run — nothing written. Add --write.');
    await db.close();
    return;
  }

  final engine = StoryEngine(
    ai: GeminiProvider(secrets: secrets, httpClient: client),
    repo: repo,
  );
  final series = await SeriesService(repo).create(
    childId: child.id,
    title: 'Naming it…',
    autoTitle: true,
    theme: world.theme,
    extraThemes: world.extraThemes,
    worldId: world.id,
    heroMode: HeroMode.surprise,
  );

  stdout.writeln('\nwriting…');
  final reader = child.copyWith(detailLevel: detail);
  var beat = await engine.takeTurn(
    child: reader,
    series: series,
    intent: StoryIntent.dice,
  );
  stdout.writeln('  1. ${beat.title}');
  var guard = 0;
  while (!beat.isFinal && guard++ < 10) {
    beat = await engine.takeTurn(
      child: reader,
      series: series,
      intent: StoryIntent.continued,
    );
    stdout.writeln('  ${beat.seq + 1}. ${beat.title}');
  }

  final saved = await repo.loadSeriesById(series.id) ?? series;
  final beats = await repo.loadBeats(series.id);
  stdout.writeln('\n"${saved.title}" — ${beats.length} chapters');

  stdout.writeln('\ndrawing…');
  final pictures =
      await IllustrationService(
        illustrator: GeminiIllustrator(secrets: secrets, httpClient: client),
        pictures: FilePictureStore(
          root: Directory(
            '${Platform.environment['USERPROFILE']}'
            '\\Documents\\Sleepytime\\pictures',
          ),
        ),
        repo: repo,
        uuid: const Uuid(),
      ).illustrate(
        series: saved,
        beats: beats,
        cast: cast,
        onProgress: (done, total) => stdout.writeln('  $done/$total'),
      );

  for (final p in pictures) {
    stdout.writeln(
      '  ${p.kind.name.padRight(8)} ${p.size} ${p.aspect}  ${p.fileKey}',
    );
  }
  stdout.writeln(
    '\nDone. Open ${child.displayName} → ${world.name} → "${saved.title}".',
  );
  client.close();
  await db.close();
}

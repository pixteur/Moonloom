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
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/images/picture_store.dart';
import 'package:moonloom/adapters/images/story_illustrator.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/illustration_service.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/prompt_builder.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/story_engine.dart';
import 'package:uuid/uuid.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\moonloom\shared_preferences.json',
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
  final only = _opt(args, '--illustrate');
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
  final cast = await repo.loadCharacters(world.id);

  stdout.writeln('child:  ${child.displayName} (${child.age})');
  stdout.writeln('world:  ${world.name}');
  stdout.writeln(
    'cast:   '
    '${cast.isEmpty ? '(none saved)' : cast.map((c) => c.name).join(', ')}',
  );
  stdout.writeln('length: $length');

  // Illustrating a story that already exists, rather than writing a new one.
  // The cover on "The Ancient Sea Knot" was lost to a 503 before 503s were
  // retried, and rewriting a seven-chapter story to recover one picture would
  // be an absurd way to fix it.
  Series? existing;
  if (only != null) {
    final all = await repo.loadSeries(child.id);
    existing = all.cast<Series?>().firstWhere(
      (s) => s!.title.toLowerCase().contains(only.toLowerCase()),
      orElse: () => null,
    );
    if (existing == null) {
      stdout.writeln('No story of ${child.displayName}\'s matching "$only".');
      await db.close();
      return;
    }
    stdout.writeln('story:  "${existing.title}" (already written)');
  }
  if (!write) {
    stdout.writeln('\nDry run — nothing written. Add --write.');
    await db.close();
    return;
  }

  final engine = StoryEngine(
    ai: GeminiProvider(secrets: secrets, httpClient: client),
    repo: repo,
  );
  final Series series;
  if (existing != null) {
    series = existing;
  } else {
    series = await SeriesService(repo).create(
      childId: child.id,
      title: 'Naming it…',
      autoTitle: true,
      theme: world.theme,
      extraThemes: world.extraThemes,
      worldId: world.id,
      heroMode: HeroMode.surprise,
      detailLevel: detail,
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
  }

  final saved = await repo.loadSeriesById(series.id) ?? series;
  final beats = await repo.loadBeats(series.id);
  stdout.writeln('\n"${saved.title}" — ${beats.length} chapters');

  stdout.writeln('\ndrawing…');
  final illustration = IllustrationService(
    illustrator: GeminiIllustrator(secrets: secrets, httpClient: client),
    pictures: FilePictureStore(
      root: Directory(
        '${Platform.environment['USERPROFILE']}'
        '\\Documents\\Moonloom\\pictures',
      ),
    ),
    repo: repo,
    uuid: const Uuid(),
  );

  // The world's look is written once, by the model that writes the stories —
  // it already knows the arc and the setting, which is the brief an art
  // director works from.
  final styled = await illustration.ensureStyleGuide(
    world,
    writeGuide: (brief) async {
      final segment = await GeminiProvider(
        secrets: secrets,
        httpClient: client,
      ).generate(StoryPrompt(system: brief, user: 'Write the art direction.'));
      return segment.storyText;
    },
  );
  if (styled.styleGuide != world.styleGuide) {
    stdout.writeln('  style: ${styled.styleGuide}\n');
  }

  final pictures = await illustration.illustrate(
    series: saved,
    beats: beats,
    world: styled,
    cast: cast,
    onProgress: (done, total) => stdout.writeln('  $done/$total'),
    onStep: (what) => stdout.writeln('  $what'),
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

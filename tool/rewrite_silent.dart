/// Write the silent stories again, with the world's real cast.
///
/// **This one costs money and replaces stories.** It only ever touches a story
/// with no cached narration in any voice — nobody has heard it, so nothing a
/// child remembers is lost. `tool/audio_coverage.dart` is the list it works
/// from and is worth reading first.
///
/// The order matters and is the point. A replacement is written in full, into
/// a new story, *before* the old one is deleted; if anything fails halfway the
/// original is still there and the half-written replacement can be thrown
/// away. Replacing in place would mean deleting seven chapters and hoping.
///
///     dart run tool/rewrite_silent.dart --child Mia
///     dart run tool/rewrite_silent.dart --child Mia --write
///     dart run tool/rewrite_silent.dart --child Mia --write --illustrate
///
/// Pictures are redrawn only with `--illustrate`, and only for stories that
/// already had some: a rewritten story's old pictures show the old cast.
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
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/illustration_service.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/story_engine.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\Moonloom\shared_preferences.json',
    );
    if (!file.existsSync()) throw StateError('No prefs at ${file.path}');
    return _StoredKeys(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> _prefs;

  @override
  Future<String?> readKey(String id) async {
    final stored = _prefs['flutter.enckey_$id'] as String?;
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

  List<String> get voices {
    final out = <String>{
      for (final v in (_prefs['flutter.known_voice_signatures'] as List? ?? []))
        v.toString(),
    };
    for (final engine in ['gemini', 'openai', 'elevenlabs']) {
      final voice = _prefs['flutter.voicename_$engine'] as String?;
      final model = _prefs['flutter.voicemodel_$engine'] as String?;
      if (voice != null && model != null && model.isNotEmpty) {
        out.add('$engine/$model/$voice');
      }
    }
    return out.toList();
  }
}

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

/// Whether any voice on this device holds narration for every chapter.
bool _hasAudio(List<Beat> beats, List<String> voices, Set<String> onDisk) {
  if (beats.isEmpty) return false;
  for (final beat in beats) {
    final voiced = voices.any((sig) {
      final keys = chapterAudioKeys(
        voiceSignature: sig,
        language: beat.language,
        text: beat.text,
        notes: beat.narration,
      );
      return keys.isNotEmpty && keys.every(onDisk.contains);
    });
    if (voiced) return true;
  }
  return false;
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final illustrate = args.contains('--illustrate');
  final childName = _opt(args, '--child');
  final home = Platform.environment['USERPROFILE'] ?? '';

  final db = AppDatabase.openIn(
    '$home'
    r'\Documents',
  );
  final repo = DriftStorageRepo(db);
  final secrets = await _StoredKeys.open();
  final client = http.Client();

  final audioDir = Directory(
    '$home'
    r'\Documents\Moonloom\audio',
  );
  final onDisk = audioDir.existsSync()
      ? audioDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet()
      : <String>{};
  final voices = secrets.voices;

  final pictures = FilePictureStore(
    root: Directory(
      '$home'
      r'\Documents\Moonloom\pictures',
    ),
  );
  final illustration = IllustrationService(
    illustrator: GeminiIllustrator(secrets: secrets, httpClient: client),
    pictures: pictures,
    repo: repo,
  );

  var rewritten = 0;
  for (final child in await repo.loadProfiles()) {
    if (childName != null &&
        child.displayName.toLowerCase() != childName.toLowerCase()) {
      continue;
    }
    stdout.writeln('\n${child.displayName}');

    for (final story in await repo.loadSeries(child.id)) {
      final beats = await repo.loadBeats(story.id);
      if (beats.isEmpty) continue;
      if (_hasAudio(beats, voices, onDisk)) {
        stdout.writeln('  ${story.title.padRight(32)} has audio — left alone');
        continue;
      }

      final world = story.worldId == null
          ? null
          : await repo.loadWorldById(story.worldId!);
      final cast = world == null
          ? const []
          : await repo.loadCharacters(world.id);
      final hadPictures = (await repo.loadImages(story.id)).isNotEmpty;

      stdout.writeln(
        '  ${story.title.padRight(32)} ${beats.length} ch  '
        '${world?.name ?? 'no world'}  '
        '${cast.isEmpty ? 'no cast' : '${cast.length} in cast'}'
        '${hadPictures ? '  (has pictures)' : ''}',
      );
      if (!write) continue;

      // The replacement is written in full before the original is touched.
      final replacement = await SeriesService(repo).create(
        childId: child.id,
        title: 'Rewriting…',
        autoTitle: true,
        theme: story.theme,
        extraThemes: story.extraThemes,
        worldId: story.worldId,
        customTheme: story.customTheme,
        heroMode: story.heroMode,
        heroName: story.heroName,
        seedSummary: story.seedSummary,
        baseLanguage: story.baseLanguage,
        bilingualEnabled: story.bilingualEnabled,
        secondaryLanguage: story.secondaryLanguage,
        bilingualBlend: story.bilingualBlend,
        detailLevel: story.detailLevel,
      );

      final engine = StoryEngine(
        ai: GeminiProvider(secrets: secrets, httpClient: client),
        repo: repo,
      );
      // The length it was, so a seven-chapter story stays seven.
      final reader = child.copyWith(
        detailLevel: story.detailLevel ?? _lengthOf(beats.length),
      );

      var ok = true;
      try {
        var beat = await engine.takeTurn(
          child: reader,
          series: replacement,
          intent: StoryIntent.dice,
          chosenTwist: beats.first.chosenTwist,
        );
        var guard = 0;
        while (!beat.isFinal && guard++ < 10) {
          beat = await engine.takeTurn(
            child: reader,
            series: replacement,
            intent: StoryIntent.continued,
          );
        }
      } catch (e) {
        ok = false;
        stdout.writeln('    failed: $e');
      }

      final fresh = await repo.loadBeats(replacement.id);
      if (!ok || fresh.isEmpty) {
        // Leave the original exactly as it was and clear the wreckage.
        await repo.deleteSeries(replacement.id);
        stdout.writeln('    original kept');
        continue;
      }

      final saved = await repo.loadSeriesById(replacement.id) ?? replacement;
      stdout.writeln('    -> "${saved.title}", ${fresh.length} chapters');

      if (illustrate && hadPictures) {
        final made = await illustration.illustrate(
          series: saved,
          beats: fresh,
          world: world,
          cast: cast.cast(),
          onStep: (what) => stdout.writeln('    $what'),
        );
        stdout.writeln('    ${made.length} pictures');
      }

      // Only now. Deleting the original takes its pictures with it, which is
      // the point: they showed the cast this rewrite exists to correct.
      await repo.deleteSeries(story.id);
      rewritten++;
    }
  }

  stdout.writeln(
    write
        ? '\nRewrote $rewritten stories.'
        : '\nDry run. Add --write, and --illustrate to redraw pictures.',
  );
  client.close();
  await db.close();
}

/// The length a story of this many chapters was asked for, for the stories
/// written before the app recorded it.
DetailLevel _lengthOf(int chapters) => switch (chapters) {
  <= 1 => DetailLevel.short,
  <= 4 => DetailLevel.medium,
  _ => DetailLevel.long,
};

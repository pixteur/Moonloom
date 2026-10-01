/// Read-only: which voice signature does each cached narration file belong to?
///
/// A cache key is a one-way hash of `voice|language|text`, so a file on disk
/// cannot say who made it. It can only be *recognised*: rebuild the key for a
/// chapter under a candidate signature and see whether that file exists.
///
/// Written because "the audio is missing from all the stories" needs a cause
/// and not a theory. Narration is keyed by voice, so a voice or a **model**
/// that changed since the audio was made orphans every file at once — the app
/// stops asking for them and nothing is deleted. The only way to tell that
/// apart from a real fault is to work out what the 745 files on disk actually
/// answer to, and compare it with what the app asks for now.
///
/// So this tries a wide grid — every engine, every TTS model the app has ever
/// defaulted to, every voice in the catalogue — against every chapter, and
/// reports which signatures are present, how many files each accounts for, and
/// how many are left over. Files left over are narration belonging to text
/// that has since been rewritten, which is a different problem with a
/// different answer.
///
///     dart run tool/cache_owners.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/adapters/tts/voice_catalog.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:sqlite3/sqlite3.dart';

/// Every TTS model this app has pointed at, in any version. A model is part of
/// the signature, so changing one is indistinguishable from changing voice as
/// far as the cache is concerned — and this is the list that makes that
/// visible rather than guessed at.
const _geminiModels = [
  'gemini-2.5-flash-preview-tts',
  'gemini-2.5-pro-preview-tts',
  'gemini-3.8-flash-tts',
  'gemini-3.8-flash-lite-tts',
  'gemini-3.8-pro-tts',
];
const _elevenModels = [
  'eleven_v3',
  'eleven_multilingual_v2',
  'eleven_turbo_v2',
];
const _openAiModels = ['gpt-4o-mini-tts', 'tts-1', 'tts-1-hd'];

NarrationNotes _notes(String? raw) {
  final json = (raw ?? '{}').trim();
  return NarrationNotes.fromJson(
    jsonDecode(json.isEmpty ? '{}' : json) as Map<String, dynamic>,
  );
}

void main() {
  final home = Platform.environment['USERPROFILE'];
  final dir = Directory('$home\\Documents\\Moonloom\\audio');
  final onDisk = dir.existsSync()
      ? {
          for (final f in dir.listSync().whereType<File>())
            f.uri.pathSegments.last,
        }
      : <String>{};

  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final engine = (prefs['flutter.voice_engine'] as String?) ?? 'gemini';
  final now =
      '$engine/${prefs['flutter.voicemodel_$engine'] ?? ''}'
      '/${prefs['flutter.voicename_$engine'] ?? ''}';

  // The grid. Voice names come from the catalogue for Gemini, and from the
  // settings for the others, where a voice is an opaque id rather than a list.
  final candidates = <String>{
    for (final model in _geminiModels)
      for (final voice in geminiVoices) 'gemini/$model/${voice.id}',
    for (final model in _elevenModels)
      if ((prefs['flutter.voicename_elevenlabs'] as String?)?.isNotEmpty ??
          false)
        'elevenlabs/$model/${prefs['flutter.voicename_elevenlabs']}',
    for (final model in _openAiModels)
      for (final voice in ['nova', 'alloy', 'shimmer', 'fable'])
        'openai/$model/$voice',
    for (final v in (prefs['flutter.known_voice_signatures'] as List? ?? []))
      v.toString(),
    now,
  };

  final db = sqlite3.open(
    '$home\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );

  final filesOf = <String, Set<String>>{};
  final chaptersOf = <String, int>{};
  final storiesOf = <String, Set<String>>{};
  var chapters = 0;

  for (final s in db.select('select id, title, base_language from series')) {
    final language = (s['base_language'] as String?) ?? 'en';
    for (final b in db.select(
      'select story_text, narration_json from beats where series_id = ?',
      [s['id']],
    )) {
      chapters++;
      for (final signature in candidates) {
        final keys = chapterAudioKeys(
          voiceSignature: signature,
          language: language,
          text: b['story_text'] as String,
          notes: _notes(b['narration_json'] as String?),
        );
        if (keys.isEmpty || !keys.every(onDisk.contains)) continue;
        filesOf.putIfAbsent(signature, () => {}).addAll(keys);
        chaptersOf[signature] = (chaptersOf[signature] ?? 0) + 1;
        storiesOf.putIfAbsent(signature, () => {}).add(s['title'] as String);
      }
    }
  }
  db.close();

  stdout.writeln('${onDisk.length} files on disk, $chapters chapters saved');
  stdout.writeln('${candidates.length} signatures tried\n');
  stdout.writeln(
    '${'signature'.padRight(46)}${'chapters'.padLeft(9)}'
    '${'files'.padLeft(7)}  stories',
  );

  final found = chaptersOf.keys.toList()
    ..sort((a, b) => chaptersOf[b]!.compareTo(chaptersOf[a]!));
  final accounted = <String>{};
  for (final signature in found) {
    accounted.addAll(filesOf[signature]!);
    stdout.writeln(
      '${signature.padRight(46)}${chaptersOf[signature].toString().padLeft(9)}'
      '${filesOf[signature]!.length.toString().padLeft(7)}  '
      '${storiesOf[signature]!.length}'
      '${signature == now ? '   <- the voice the app asks for now' : ''}',
    );
  }

  if (!found.contains(now)) {
    stdout.writeln(
      '\n${now.padRight(46)}${'0'.padLeft(9)}${'0'.padLeft(7)}  '
      '0   <- the voice the app asks for now',
    );
  }

  final orphans = onDisk.difference(accounted);
  stdout.writeln(
    '\n${accounted.length} of ${onDisk.length} files belong to a chapter as it '
    'is written today.',
  );
  if (orphans.isNotEmpty) {
    stdout.writeln(
      '${orphans.length} belong to text that has since been rewritten — real '
      'recordings of words no chapter says any more.',
    );
  }
}

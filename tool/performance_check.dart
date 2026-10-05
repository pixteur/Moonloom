/// Does a real chapter come out of the real voice adapter as a performance —
/// the narrator reading and acting, the hero in their own voice — with every
/// word the story's and no direction spoken?
///
/// Mocks prove the request has the right shape; only the speaker proves it
/// sounds right. So this writes a fresh chapter through the real engine (in
/// memory, nothing saved) — which also checks that the editorial pass fills in
/// who speaks each line — then reads it through [GeminiTtsSynthesizer] twice:
/// once with the narrator acting everyone, once with the hero in a designed
/// voice. Each recording is transcribed and compared with the chapter.
///
///     dart run tool/performance_check.dart --hero-voice voice_wt3oe1lkcc7c
///
/// Writes both recordings to the desktop. Costs one chapter, two syntheses and
/// two transcriptions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/performance.dart';
import 'package:moonloom/domain/prompt_builder.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/story_engine.dart';

import '../test/support/in_memory_storage_repo.dart';

class _Keys implements SecretStore {
  _Keys(this._prefs);
  final Map<String, dynamic> _prefs;
  @override
  Future<String?> readKey(String id) async {
    final s = _prefs['flutter.enckey_$id'] as String?;
    return s == null ? null : dpapiUnprotect(base64.decode(s));
  }

  @override
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;
  @override
  Future<void> writeKey(String id, String key) async {}
  @override
  Future<void> deleteKey(String id) async {}
}

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

/// Lower-case words, for comparing a transcript with the page.
List<String> _words(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-zà-ÿœæç' ]+"), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

Future<String> _transcribe(http.Client c, String key, List<int> wav) async {
  final r = await c.post(
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.8-flash:generateContent',
    ),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Transcribe only the words spoken in this audio, word for '
                  'word. Do not describe non-speech sounds. Output only the '
                  'spoken words.',
            },
            {
              'inline_data': {
                'mime_type': 'audio/wav',
                'data': base64.encode(wav),
              },
            },
          ],
        },
      ],
    }),
  );
  if (r.statusCode != 200) return '[transcription ${r.statusCode}]';
  final parts =
      ((((jsonDecode(r.body) as Map)['candidates'] as List).first
                  as Map)['content']
              as Map)['parts']
          as List;
  return parts.map((p) => (p as Map)['text'] ?? '').join().trim();
}

Future<void> main(List<String> args) async {
  final heroVoice = _opt(args, '--hero-voice');
  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final secrets = _Keys(prefs);
  final key = (await secrets.readKey('gemini'))!;
  final narratorVoice =
      (prefs['flutter.voicename_gemini'] as String?) ?? 'Sulafat';

  // Mia, Pip's world and its cast, copied into memory.
  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE']}\\Documents',
  );
  final real = DriftStorageRepo(db);
  final child = (await real.loadProfiles()).cast<ChildProfile?>().firstWhere(
    (c) => c!.displayName == 'Mia',
  )!;
  final world = (await real.loadWorlds(
    child.id,
  )).firstWhere((w) => w.name == "Pip's Adventures");
  final cast = await real.loadCharacters(world.id);
  await db.close();
  final repo = InMemoryStorageRepo();
  await repo.saveProfile(child);
  await repo.saveWorld(world);
  for (final c in cast) {
    await repo.saveCharacter(c);
  }

  final client = http.Client();
  final engine = StoryEngine(
    ai: GeminiProvider(secrets: secrets, httpClient: client),
    repo: repo,
  );
  final Series series = await SeriesService(repo).create(
    childId: child.id,
    title: 'Naming it…',
    theme: world.theme,
    autoTitle: true,
    worldId: world.id,
    heroMode: HeroMode.namedHero,
    heroName: 'Pip',
    detailLevel: child.detailLevel,
  );
  // Keep writing until a chapter has dialogue — a chapter of pure narration
  // exercises neither the speaker attribution nor the hero's voice.
  late Beat beat;
  for (var turn = 0; turn < 4; turn++) {
    stdout.writeln('writing chapter ${turn + 1}…');
    beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: turn == 0 ? StoryIntent.dice : StoryIntent.continued,
    );
    if (engine.lastFallbackReason != null) {
      stdout.writeln('FELL BACK: ${engine.lastFallbackReason}');
      return;
    }
    if (RegExp('["“«]').hasMatch(beat.text)) break;
  }
  final notes = beat.narration;
  final paras = beat.text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final quotes = paras.fold<int>(0, (n, p) => n + quotesIn(p));
  final resolved = attributeQuotes(paras, notes.speakers);
  final claimed = resolved
      .expand((s) => s.split(','))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != '?')
      .length;
  final words = beat.text.split(RegExp(r'\s+')).length;
  final spokenWords = RegExp('["“«]([^"”»]*)["”»]')
      .allMatches(beat.text)
      .fold<int>(0, (n, m) => n + m.group(1)!.split(RegExp(r'\s+')).length);
  stdout.writeln(
    '  ${paras.length} paragraphs, $quotes quoted lines, '
    '${notes.speakers.length} attributions written',
  );
  stdout.writeln(
    '  dialogue: ${(100 * spokenWords / words).round()}% of $words words '
    '(asked for ${(dialogueShare * 100).round()}%)',
  );
  stdout.writeln('  lines claimed by their words: $claimed of $quotes');
  stdout.writeln('  resolved: $resolved');

  final chunks = narratedChunks(beat.text, notes, sizeChunks);
  // The passage where Pip speaks most, so his voice is actually exercised.
  int pipLines(NarratedChunk c) => c.speakers
      .expand((s) => s.split(','))
      .where((n) => n.trim() == 'Pip')
      .length;
  final chunk =
      (chunks.toList()..sort((a, b) => pipLines(b).compareTo(pipLines(a))))
          .first;
  stdout.writeln(
    '  using a passage of ${chunk.text.length} characters, '
    "${pipLines(chunk)} of them Pip's lines",
  );
  final out = Directory(
    '${Platform.environment['USERPROFILE']}\\Desktop\\moonloom-voices',
  )..createSync(recursive: true);

  for (final (label, hero) in [
    ('narrator acting everyone', null),
    if (heroVoice != null) ('Pip in his own voice', heroVoice),
  ]) {
    final parts = chunk.paragraphCues == null
        ? const <SpeechPart>[]
        : performParagraphs(
            chunk.text,
            cues: chunk.paragraphCues!,
            speakers: chunk.speakers,
            characterVoices: notes.characterVoices,
            standingStyle: notes.style,
            heroName: hero == null ? null : 'Pip',
          );
    final synth = GeminiTtsSynthesizer(
      secrets: secrets,
      httpClient: client,
      voiceName: narratorVoice,
      model: 'gemini-3.8-flash-tts',
      heroName: hero == null ? null : 'Pip',
      heroVoice: hero,
    );
    final heroParts = parts.where((p) => p.voice == PartVoice.hero).length;
    final acted = parts.where((p) => p.style.contains('voicing')).length;
    stdout.writeln(
      '\n$label: ${parts.length} parts, $heroParts in the hero\'s voice, '
      '$acted acted by the narrator',
    );
    final wav = await synth.synthesize(chunk.text, parts: parts);
    File('${out.path}\\chapter - $label.wav').writeAsBytesSync(wav);
    final heard = await _transcribe(client, key, wav);

    // Every word heard should be on the page, and almost every word on the
    // page should be heard.
    final page = _words(chunk.text).toSet();
    final spoken = _words(heard);
    final extra = spoken.where((w) => !page.contains(w)).toSet();
    final missing = page.difference(spoken.toSet());
    stdout.writeln(
      '  ${((wav.length - 44) / 48000).toStringAsFixed(1)} s, '
      '${spoken.length} words heard',
    );
    stdout.writeln(
      extra.isEmpty
          ? '  ✓ no word was spoken that is not on the page'
          : '  ✗ SPOKEN BUT NOT ON THE PAGE: ${extra.take(20).join(', ')}',
    );
    stdout.writeln(
      '  ${missing.length} of ${page.length} distinct words on the page not '
      'heard${missing.isEmpty ? '' : ': ${missing.take(12).join(', ')}'}',
    );
  }
  stdout.writeln('\nListen: ${out.path}');
  client.close();
}

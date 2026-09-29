import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/export/sleepy_codec.dart';
import 'package:moonloom/adapters/tts/audio_cache.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/sleepy_service.dart';

import '../support/in_memory_storage_repo.dart';

/// Exports have to look for narration where playback actually put it.
///
/// When they disagreed, a fully-downloaded story exported as "no narration
/// saved yet". It hid because the only chapters under test had **no narration
/// cues** — one chunk, empty suffix, so the whole-chapter key and the chunk key
/// happened to be the same string. Every case here therefore uses a chapter
/// with cues, which is what the editorial pass now produces for real stories.
class _MemCache implements AudioCache {
  final Map<String, Uint8List> entries = {};
  @override
  Future<Uint8List?> get(String key) async => entries[key];
  @override
  Future<void> put(String key, Uint8List bytes) async => entries[key] = bytes;
}

void main() {
  const voiceSig = 'gemini/gemini-2.5-flash-preview-tts/Aoede';
  const lang = 'en';

  // Two paragraphs whose *feeling* differs, so the chunker splits them — the
  // shape that broke the exports.
  const text =
      'Leo heard a humming under the floor.\n\n'
      'He curled up and let the sound carry him to sleep.';
  const notes = NarrationNotes(
    style: 'gentle bedtime',
    cues: [
      NarrationCue(pace: 'normal', emotion: 'curious'),
      NarrationCue(pace: 'slow', emotion: 'sleepy', volume: 'hushed'),
    ],
  );
  const beat = Beat(
    id: 'b0',
    seriesId: 's1',
    childId: 'kid',
    seq: 0,
    intent: StoryIntent.dice,
    text: text,
    summary: 'ch0',
    isFinal: true,
    narration: notes,
  );
  const series = Series(
    id: 's1',
    childId: 'kid',
    title: 'Humming Floor',
    theme: StoryTheme.cozy,
  );

  List<String> keys() => chapterAudioKeys(
    voiceSignature: voiceSig,
    language: lang,
    text: text,
    notes: notes,
  );

  /// A repo + cache holding the chapter, narrated exactly as playback would.
  Future<(InMemoryStorageRepo, _MemCache)> narrated() async {
    final repo = InMemoryStorageRepo();
    await repo.saveSeries(series);
    await repo.saveBeat(beat);
    final cache = _MemCache();
    final chunkKeys = keys();
    for (var i = 0; i < chunkKeys.length; i++) {
      await cache.put(
        chunkKeys[i],
        Uint8List.fromList(List.filled(120, i + 1)),
      );
    }
    return (repo, cache);
  }

  test('a cued chapter is more than one cache entry', () {
    // Guards the premise of every other test here: if this ever collapses to
    // one chunk, these tests stop covering the bug they were written for.
    expect(keys().length, greaterThan(1));
    expect(
      keys(),
      isNot(contains(audioCacheKey('$voiceSig|$lang|${text.trim()}'))),
      reason: 'the whole-chapter key is not one of the keys playback writes',
    );
  });

  test('an export finds a cued chapter — every chunk of it', () async {
    // This is the regression: before the fix the archive came out with no
    // audio at all, because the export asked for a key nothing ever wrote.
    // (Asserted through exportBytes, the one export that doesn't write to the
    // real library folder — the lookup underneath is shared by all three.)
    final (repo, cache) = await narrated();
    final bytes = await SleepyService(
      repo,
      cache,
    ).exportBytes(series, language: lang, voiceSignature: voiceSig);

    final archive = decodeSleepy(bytes);
    expect(archive.audio, hasLength(keys().length));
    expect(archive.audio.values, containsAll(cache.entries.values));
  });

  test('a half-cached chapter is not exportable', () async {
    final (repo, cache) = await narrated();
    cache.entries.remove(keys().last); // lost the second chunk

    // Nothing at all, rather than a story that stops mid-sentence.
    final bytes = await SleepyService(
      repo,
      cache,
    ).exportBytes(series, language: lang, voiceSignature: voiceSig);
    expect(decodeSleepy(bytes).audio, isEmpty);

    // And the whole-story exports say so instead of writing a truncated file.
    await expectLater(
      SleepyService(repo, cache).exportAudiobook(
        series,
        language: lang,
        voiceSignature: voiceSig,
        mimeType: 'audio/mpeg',
        author: 'test',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    '.sleepy carries every chunk and puts them back where playback looks',
    () async {
      final (repo, cache) = await narrated();
      final bytes = await SleepyService(
        repo,
        cache,
      ).exportBytes(series, language: lang, voiceSignature: voiceSig);

      final destRepo = InMemoryStorageRepo();
      final destCache = _MemCache();
      final imported = await SleepyService(
        destRepo,
        destCache,
      ).importBytes(bytes, 'kid2');

      // The notes travelled, so the recipient computes the same keys...
      final beats = await destRepo.loadBeats(imported.id);
      expect(beats.single.narration.cues.length, 2);
      expect(beats.single.narration.style, 'gentle bedtime');
      // ...and every chunk is sitting under one of them.
      expect(destCache.entries.keys.toSet(), keys().toSet());
      for (final key in keys()) {
        expect(destCache.entries[key], cache.entries[key]);
      }
    },
  );

  test('a v1 file (one blob per chapter) still imports', () async {
    // Hand-built legacy manifest: `audio` is a single name and there are no
    // narration notes. Placeable only because a cue-less chapter is one chunk.
    const plain = 'The moon was bright.';
    final repo = InMemoryStorageRepo();
    final cache = _MemCache();
    await repo.saveSeries(series);
    await repo.saveBeat(
      const Beat(
        id: 'b0',
        seriesId: 's1',
        childId: 'kid',
        seq: 0,
        intent: StoryIntent.dice,
        text: plain,
        summary: 'ch0',
        isFinal: true,
      ),
    );
    final audio = Uint8List.fromList(List.filled(64, 9));
    await cache.put(audioCacheKey('$voiceSig|$lang|$plain'), audio);

    final bytes = await SleepyService(
      repo,
      cache,
    ).exportBytes(series, language: lang, voiceSignature: voiceSig);

    final destCache = _MemCache();
    await SleepyService(
      InMemoryStorageRepo(),
      destCache,
    ).importBytes(bytes, 'kid2');
    expect(
      destCache.entries[audioCacheKey('$voiceSig|$lang|$plain')],
      audio,
      reason: 'a cue-less chapter keys the same either way',
    );
  });
}

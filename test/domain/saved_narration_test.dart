import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/audio_cache.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:moonloom/domain/saved_narration.dart';

/// Narration is keyed by the voice that spoke it, so changing voice makes
/// every downloaded chapter look undownloaded. Nothing is deleted — 600 MB of
/// it was still on disk — but the app stopped asking for it, which reads as
/// "the story audio from last week is missing".
class _MemCache implements AudioCache {
  final Map<String, Uint8List> entries = {};
  @override
  Future<Uint8List?> get(String key) async => entries[key];
  @override
  Future<void> put(String key, Uint8List bytes) async => entries[key] = bytes;
}

void main() {
  const oldVoice = 'gemini/gemini-2.5-flash-preview-tts/Aoede';
  const newVoice = 'elevenlabs/eleven_v3/MF3mGyEYCl7XYWbV9V6O';
  const language = 'en';

  const beat = Beat(
    id: 'b0',
    seriesId: 's1',
    childId: 'kid',
    seq: 0,
    intent: StoryIntent.dice,
    text: 'Leo heard a humming under the floor.\n\nHe curled up and slept.',
    summary: 'ch0',
    narration: NarrationNotes(
      cues: [
        NarrationCue(emotion: 'curious'),
        NarrationCue(emotion: 'sleepy'),
      ],
    ),
  );

  /// Record the chapter in [voice], the way playback would.
  void record(_MemCache cache, String voice) {
    for (final key in chapterAudioKeys(
      voiceSignature: voice,
      language: language,
      text: beat.text,
      notes: beat.narration,
    )) {
      cache.entries[key] = Uint8List.fromList([1, 2, 3]);
    }
  }

  test('a chapter saved in the old voice is still found after a change', () {
    final cache = _MemCache();
    record(cache, oldVoice);
    expect(
      SavedNarration(cache).find(
        beat,
        language: language,
        preferred: newVoice,
        alternatives: const [oldVoice],
      ),
      completion(
        isA<SavedTake>().having((t) => t.voiceSignature, 'voice', oldVoice),
      ),
    );
  });

  test('the current voice wins when it has its own recording', () async {
    final cache = _MemCache();
    record(cache, oldVoice);
    record(cache, newVoice);
    final take = await SavedNarration(cache).find(
      beat,
      language: language,
      preferred: newVoice,
      alternatives: const [oldVoice],
    );
    expect(take!.voiceSignature, newVoice);
  });

  test('a half-recorded chapter does not count, in any voice', () async {
    final cache = _MemCache();
    record(cache, oldVoice);
    cache.entries.remove(cache.entries.keys.last); // lost one chunk
    expect(
      await SavedNarration(cache).isSavedAnywhere(
        beat,
        language: language,
        preferred: newVoice,
        alternatives: const [oldVoice],
      ),
      isFalse,
      reason: 'half a chapter stops mid-sentence',
    );
  });

  test('nothing anywhere is nothing', () async {
    expect(
      await SavedNarration(_MemCache()).isSavedAnywhere(
        beat,
        language: language,
        preferred: newVoice,
        alternatives: const [oldVoice],
      ),
      isFalse,
    );
  });
}

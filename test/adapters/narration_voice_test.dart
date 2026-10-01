import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/audio_kind.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';

/// Two things that made a library full of narration look empty.
///
/// Narration is keyed by the voice that spoke it, so changing voice makes every
/// chapter ever downloaded look undownloaded. Nothing is deleted; the app stops
/// asking. Measured on the real library: 745 files, 27 chapters' worth, under
/// two voices — and the download badge showing a plain tick for all of them
/// while playback, which reads in the voice you chose, would re-record the
/// ones belonging to the other voice.
///
/// A story is still read in the voice that was chosen. That is the rule the
/// cache key exists for and it has not changed. What changed is that the app
/// now says which voice holds a recording instead of implying it holds them
/// all.
void main() {
  const chosen = 'gemini/gemini-3.8-flash-lite-tts/Sulafat';
  const language = 'en';

  /// Silence as a 16-bit mono RIFF file, the shape Gemini returns.
  Uint8List wav(int frames, {int rate = 24000}) {
    final out = BytesBuilder();
    final data = Uint8List(frames * 2);
    void ascii(String s) => out.add(s.codeUnits);
    void u32(int v) => out.add(
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little),
    );
    void u16(int v) => out.add(
      Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little),
    );
    ascii('RIFF');
    u32(36 + data.length);
    ascii('WAVEfmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    ascii('data');
    u32(data.length);
    out.add(data);
    return out.toBytes();
  }

  /// An MP3-looking blob: not RIFF, which is all the format sniff reads.
  Uint8List mp3() =>
      Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, ...List.filled(400, 0x55)]);

  // The trap this family of bugs comes from: a key built by hand beside a key
  // built by `chapterAudioKeys` that are *nearly* the same. Exports once keyed
  // on a whole chapter's text, fully downloaded stories reported no narration
  // saved, and it hid for weeks because a chapter without cues is a single
  // chunk whose two keys happen to be identical. So this uses a chapter that
  // really does split.
  group('one way to build a cache key', () {
    const notes = NarrationNotes(
      cues: [
        NarrationCue(emotion: 'hushed', pace: 'slow'),
        NarrationCue(emotion: 'delighted', pace: 'quick'),
      ],
    );
    const twoParagraphs =
        'Pip swam out past the kelp.\n\nThen the reef lit up at once.';

    test('the chunk key and the chapter key are the same question', () {
      final chunks = narratedChunks(twoParagraphs, notes, sizeChunks);
      expect(
        chunks.length,
        greaterThan(1),
        reason: 'a cue-less chapter is one chunk and would prove nothing',
      );
      expect(
        chapterAudioKeys(
          voiceSignature: chosen,
          language: language,
          text: twoParagraphs,
          notes: notes,
        ),
        [
          for (final chunk in chunks)
            chunkAudioKey(
              voiceSignature: chosen,
              language: language,
              chunk: chunk,
            ),
        ],
      );
    });

    test('a different voice is a different key', () {
      final a = chapterAudioKeys(
        voiceSignature: chosen,
        language: language,
        text: twoParagraphs,
        notes: notes,
      );
      final b = chapterAudioKeys(
        voiceSignature: 'elevenlabs/eleven_v3/MF3mGyEYCl7XYWbV9V6O',
        language: language,
        text: twoParagraphs,
        notes: notes,
      );
      expect(a, isNot(b), reason: 'why a voice change looks like data loss');
    });
  });

  // A recording outlives the voice that made it, so the live synthesizer is
  // not a reliable witness to what a cached file is. A WAV announced as MP3
  // does not play, and the failure is silent.
  group('the format comes from the bytes', () {
    test('RIFF is WAV whatever the synthesizer says', () {
      expect(audioMimeOf(wav(100)), 'audio/wav');
      expect(isWavBytes(wav(100)), isTrue);
    });

    test('anything else is treated as MPEG', () {
      expect(audioMimeOf(mp3()), 'audio/mpeg');
      expect(isWavBytes(mp3()), isFalse);
    });

    test('a runt buffer does not throw', () {
      expect(audioMimeOf(Uint8List(0)), 'audio/mpeg');
      expect(isWavBytes(Uint8List.fromList([0x52, 0x49])), isFalse);
    });
  });
}

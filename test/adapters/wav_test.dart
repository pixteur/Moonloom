import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

/// The parser has to walk the chunk list rather than assume a 44-byte header,
/// because a writer is free to slip a `LIST` or `fact` chunk in first and the
/// shortcut then reads metadata as audio — silently, as noise.
void main() {
  Uint8List pcm(int frames, {int channels = 1}) {
    final samples = Int16List(frames * channels);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (i * 137) % 30000 - 15000;
    }
    return Uint8List.sublistView(samples);
  }

  test('reads rate, channels and samples back out of a plain WAV', () {
    final audio = decodeWav(pcmToWav(pcm(1000), sampleRate: 24000));
    expect(audio.sampleRate, 24000);
    expect(audio.channels, 1);
    expect(audio.frames, 1000);
    expect(audio.duration.inMilliseconds, closeTo(41, 1));
  });

  test('samples survive the round trip byte for byte', () {
    final raw = pcm(64);
    final audio = decodeWav(pcmToWav(raw));
    expect(Uint8List.sublistView(audio.samples), raw);
  });

  test('stereo is kept interleaved', () {
    final audio = decodeWav(pcmToWav(pcm(500, channels: 2), channels: 2));
    expect(audio.channels, 2);
    expect(audio.frames, 500);
    expect(audio.samples.length, 1000);
  });

  test('a chunk between fmt and data is skipped, not read as audio', () {
    final plain = pcmToWav(pcm(100));
    // Splice a LIST chunk in ahead of `data`, which starts 36 bytes in.
    const dataAt = 36;
    final list = BytesBuilder()
      ..add('LIST'.codeUnits)
      ..add([8, 0, 0, 0])
      ..add('INFOxxxx'.codeUnits);
    final spliced = BytesBuilder()
      ..add(plain.sublist(0, dataAt))
      ..add(list.toBytes())
      ..add(plain.sublist(dataAt));

    final audio = decodeWav(spliced.toBytes());
    expect(audio.frames, 100);
    expect(Uint8List.sublistView(audio.samples), pcm(100));
  });

  test('an odd-length chunk is followed by a pad byte', () {
    final plain = pcmToWav(pcm(100));
    const dataAt = 36;
    final odd = BytesBuilder()
      ..add('note'.codeUnits)
      ..add([3, 0, 0, 0])
      ..add([1, 2, 3, 0]); // 3 bytes of payload, then the pad
    final spliced = BytesBuilder()
      ..add(plain.sublist(0, dataAt))
      ..add(odd.toBytes())
      ..add(plain.sublist(dataAt));

    expect(decodeWav(spliced.toBytes()).frames, 100);
  });

  test('a data size of 0xFFFFFFFF is clamped to what is there', () {
    final wav = pcmToWav(pcm(100));
    // The data chunk's length field sits at offset 40.
    ByteData.sublistView(wav).setUint32(40, 0xFFFFFFFF, Endian.little);
    expect(decodeWav(wav).frames, 100);
  });

  test('a half sample at the end is dropped rather than read', () {
    final wav = pcmToWav(pcm(100));
    expect(decodeWav(wav.sublist(0, wav.length - 1)).frames, 99);
  });

  group('joining and trimming', () {
    WavAudio clip(List<int> samples, {int rate = 24000, int channels = 1}) =>
        WavAudio(
          samples: Int16List.fromList(samples),
          sampleRate: rate,
          channels: channels,
        );

    test('joins clips end to end', () {
      final joined = joinWav([
        clip([1, 2, 3]),
        clip([4, 5]),
      ]);
      expect(joined.samples, [1, 2, 3, 4, 5]);
      expect(joined.sampleRate, 24000);
    });

    test('refuses to join mismatched clips', () {
      expect(
        () => joinWav([
          clip([1]),
          clip([2], rate: 44100),
        ]),
        throwsA(isA<WavFormatException>()),
      );
      expect(() => joinWav([]), throwsA(isA<WavFormatException>()));
    });

    test('cuts dead air off the end, keeping half a second', () {
      // Half a second of tone, then ten seconds of nothing — the shape a
      // glitched chapter came back in.
      final samples = Int16List(24000 * 11);
      for (var i = 0; i < 12000; i++) {
        samples[i] = 8000;
      }
      final trimmed = trimTrailingSilence(
        WavAudio(samples: samples, sampleRate: 24000, channels: 1),
      );
      expect(trimmed.duration.inMilliseconds, closeTo(1000, 40));
    });

    test('leaves a quiet passage in the middle alone', () {
      final samples = Int16List(24000 * 6);
      for (var i = 0; i < 12000; i++) {
        samples[i] = 8000; // speech
      }
      for (var i = 24000 * 5; i < 24000 * 5 + 12000; i++) {
        samples[i] = 8000; // more speech, after five quiet seconds
      }
      final trimmed = trimTrailingSilence(
        WavAudio(samples: samples, sampleRate: 24000, channels: 1),
      );
      expect(trimmed.duration.inMilliseconds, closeTo(6000, 40));
    });

    test('a clip with nothing to trim comes back whole', () {
      final samples = Int16List(2400)..fillRange(0, 2400, 9000);
      final audio = WavAudio(samples: samples, sampleRate: 24000, channels: 1);
      expect(trimTrailingSilence(audio).samples.length, 2400);
    });

    test('a clip that is entirely silence is left as it is', () {
      final audio = WavAudio(
        samples: Int16List(24000),
        sampleRate: 24000,
        channels: 1,
      );
      expect(trimTrailingSilence(audio).samples.length, 24000);
    });

    test('stereo keeps whole frames', () {
      final samples = Int16List(4000);
      samples[0] = 9000;
      samples[1] = 9000;
      final trimmed = trimTrailingSilence(
        WavAudio(samples: samples, sampleRate: 8000, channels: 2),
      );
      expect(trimmed.samples.length.isEven, isTrue);
    });
  });

  group('rejects what it cannot convert, saying what it found', () {
    test('not a RIFF file', () {
      expect(
        () => decodeWav(Uint8List.fromList(List.filled(64, 0x41))),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('8-bit samples', () {
      final wav = pcmToWav(pcm(100), bitsPerSample: 8);
      expect(
        () => decodeWav(wav),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('8-bit'),
          ),
        ),
      );
    });

    test('IEEE float', () {
      final wav = pcmToWav(pcm(100));
      ByteData.sublistView(wav).setUint16(20, 3, Endian.little);
      expect(
        () => decodeWav(wav),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('IEEE float'),
          ),
        ),
      );
    });

    test('no data chunk', () {
      expect(
        () => decodeWav(pcmToWav(Uint8List(0)).sublist(0, 36)),
        throwsA(isA<WavFormatException>()),
      );
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

void main() {
  group('audio compression round-trip', () {
    test('WAV survives delta+gzip exactly', () {
      // A WAV with varied 16-bit samples (incl. negatives + wraparound edges).
      final pcm = BytesBuilder();
      final view = ByteData(2);
      for (var i = 0; i < 5000; i++) {
        final s = ((i * 37) % 65536) - 32768; // sweeps full int16 range
        view.setInt16(0, s, Endian.little);
        pcm.add(view.buffer.asUint8List());
      }
      final wav = pcmToWav(pcm.toBytes(), sampleRate: 24000);

      final packed = compressAudio(wav);
      expect(packed.length, lessThan(wav.length)); // actually smaller
      expect(decompressAudio(packed), wav); // and lossless
    });

    test('odd-length PCM tail is preserved', () {
      // 45 header+... make total length odd after the 44-byte header.
      final wav = Uint8List.fromList([
        ...pcmToWav(Uint8List.fromList([1, 2, 3, 4]), sampleRate: 24000),
        0x7F, // extra trailing byte
      ]);
      expect(decompressAudio(compressAudio(wav)), wav);
    });

    test('non-WAV (mp3-ish) bytes still round-trip', () {
      final mp3 = Uint8List.fromList(
        List.generate(2000, (i) => (i * 13) % 256),
      );
      expect(decompressAudio(compressAudio(mp3)), mp3);
    });

    test('legacy uncompressed bytes pass through unchanged', () {
      final raw = pcmToWav(Uint8List.fromList([9, 9, 9, 9]), sampleRate: 24000);
      expect(decompressAudio(raw), raw); // no SZ1 magic → returned as-is
    });
  });
}

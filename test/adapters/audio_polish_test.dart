import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/audio_polish.dart';

/// A 24 kHz mono 16-bit WAV, the shape Gemini TTS returns.
Uint8List wav(List<int> samples, {int rate = 24000}) {
  final out = Uint8List(44 + samples.length * 2);
  final view = ByteData.sublistView(out);
  out.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, 36 + samples.length * 2, Endian.little);
  out.setRange(8, 12, 'WAVE'.codeUnits);
  out.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, rate, Endian.little);
  view.setUint32(28, rate * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  out.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(44 + i * 2, samples[i].clamp(-32768, 32767), Endian.little);
  }
  return out;
}

List<int> _speech(int samples, double amplitude, {int seed = 1}) {
  final rng = Random(seed);
  return [
    for (var i = 0; i < samples; i++)
      (sin(i / 8) * amplitude * 32767 * (0.7 + rng.nextDouble() * 0.3)).round(),
  ];
}

List<int> _silence(int samples) => List.filled(samples, 0);

int _sampleCount(Uint8List w) => (w.length - 44) ~/ 2;
double _seconds(Uint8List w) => _sampleCount(w) / 24000;

double _rms(Uint8List w, int fromSample, int toSample) {
  final view = ByteData.sublistView(w);
  var sum = 0.0;
  final end = min(toSample, _sampleCount(w));
  for (var i = fromSample; i < end; i++) {
    final v = view.getInt16(44 + i * 2, Endian.little) / 32768.0;
    sum += v * v;
  }
  final n = end - fromSample;
  return n <= 0 ? 0 : sqrt(sum / n);
}

void main() {
  group('what it leaves alone', () {
    test(
      'an MP3 is returned untouched — those samples are not ours to read',
      () {
        final mp3 = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, 1, 2, 3, 4]);
        expect(polishNarration(mp3), same(mp3));
      },
    );

    test('one unbroken run of speech has nothing to fix', () {
      final one = wav(_speech(24000, 0.3));
      expect(polishNarration(one), same(one));
    });

    test('something too short to be a WAV does not throw', () {
      final stub = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);
      expect(polishNarration(stub), same(stub));
    });
  });

  group('the pause between paragraphs', () {
    // The measured complaint: paragraph breaks came back at 500-760 ms,
    // sentence breaks at 160-260 ms, and a child cannot hear the difference.
    test('a paragraph-length gap is lengthened, a sentence gap is not', () {
      const rate = 24000;
      final source = [
        ..._speech(rate, 0.3),
        ..._silence(rate ~/ 5), // 200 ms — a sentence break
        ..._speech(rate, 0.3, seed: 2),
        ..._silence(rate ~/ 2), // 500 ms — a paragraph break
        ..._speech(rate, 0.3, seed: 3),
      ];
      final before = wav(source);
      final after = polishNarration(before);

      // The 500 ms gap becomes 900 ms; the 200 ms one is left where it is.
      expect(_seconds(after) - _seconds(before), closeTo(0.4, 0.05));
    });

    test('a chapter of several paragraphs gains one pause each', () {
      const rate = 24000;
      final source = <int>[];
      for (var i = 0; i < 4; i++) {
        source.addAll(_speech(rate, 0.3, seed: i));
        if (i < 3) source.addAll(_silence(rate ~/ 2));
      }
      final after = polishNarration(wav(source));
      expect(_seconds(after) - _seconds(wav(source)), closeTo(1.2, 0.1));
    });
  });

  group('the slow drift in level', () {
    test('a reading that gets louder comes back even', () {
      // Two minutes of speech climbing from 0.15 to 0.45 amplitude — the
      // shape `tool/audio_shape.dart` measured on real Gemini output.
      const rate = 24000;
      const bands = 16;
      final source = <int>[];
      for (var b = 0; b < bands; b++) {
        final amp = 0.15 + (0.30 * b / (bands - 1));
        source.addAll(_speech(rate * 8, amp, seed: b));
        if (b < bands - 1) source.addAll(_silence(rate ~/ 2));
      }
      final before = wav(source);
      final after = polishNarration(before);

      double driftOf(Uint8List w) {
        final n = _sampleCount(w);
        final first = _rms(w, n ~/ 8, n ~/ 4);
        final last = _rms(w, n * 3 ~/ 4, n * 7 ~/ 8);
        return 20 * (log(last / first) / ln10);
      }

      expect(driftOf(before), greaterThan(6));
      expect(driftOf(after).abs(), lessThan(driftOf(before) - 3));
    });

    test('it never moves the level more than the cap allows', () {
      // A deliberately extreme case: near-silence next to a loud passage.
      // The correction is bounded so it can never act like a compressor and
      // haul a whispered line up to a shout.
      const rate = 24000;
      final source = [
        ..._speech(rate * 8, 0.02),
        ..._silence(rate ~/ 2),
        ..._speech(rate * 8, 0.6, seed: 9),
      ];
      final after = polishNarration(wav(source));
      final n = _sampleCount(after);
      final quiet = _rms(after, rate, rate * 6);
      final loud = _rms(after, n - rate * 6, n - rate);
      // Still clearly quieter than the loud passage: the dynamic survives.
      expect(20 * (log(loud / quiet) / ln10), greaterThan(10));
    });
  });

  test('the header describes the body it actually has', () {
    const rate = 24000;
    final after = polishNarration(
      wav([
        ..._speech(rate, 0.3),
        ..._silence(rate ~/ 2),
        ..._speech(rate, 0.3, seed: 2),
      ]),
    );
    final view = ByteData.sublistView(after);
    expect(view.getUint32(40, Endian.little), after.length - 44);
    expect(view.getUint32(4, Endian.little), after.length - 8);
    expect(view.getUint16(34, Endian.little), 16);
  });
}

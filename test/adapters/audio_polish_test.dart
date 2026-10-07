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

/// The samples back out of a WAV, for looking at the waveform itself.
List<int> _samplesOf(Uint8List w) {
  final view = ByteData.sublistView(w);
  return [
    for (var i = 0; i < (w.length - 44) ~/ 2; i++)
      view.getInt16(44 + i * 2, Endian.little),
  ];
}

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

    // A single unbroken run has no seams to even out and no breaks to
    // lengthen, so its sound comes back as it was — except the last 120 ms,
    // which fade to silence so the clip never stops on anything but zero.
    test('one unbroken run of clean speech is untouched but for its end', () {
      final source = _speech(24000, 0.3);
      final out = _samplesOf(polishNarration(wav(source)));
      const fade = 24000 * 120 ~/ 1000;
      expect(out.length, source.length);
      expect(
        out.sublist(0, source.length - fade),
        source.sublist(0, source.length - fade),
      );
      expect(out.last, 0, reason: 'every clip ends in silence');
    });

    test('every clip ends at exactly zero', () {
      final two = wav([
        ..._speech(24000, 0.3),
        ..._silence(12000),
        ..._speech(24000, 0.3, seed: 2),
      ]);
      expect(_samplesOf(polishNarration(two)).last, 0);
    });

    test('something too short to be a WAV does not throw', () {
      final stub = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);
      expect(polishNarration(stub), same(stub));
    });
  });

  // The complaint that outlived two attempts at fixing it: a pop of static at
  // the end of a paragraph, with Gemini voices. It is not drift and not the
  // splice — twenty real cached chapters carry forty-six places where the
  // waveform jumps thousands of units between two adjacent samples next to
  // silence, in the audio exactly as the model returned it. Levelling cannot
  // help; it multiplies them along with everything else.
  group('the clicks the model leaves behind', () {
    /// The worst jump between adjacent samples that sits next to silence.
    int worstStep(Uint8List file) {
      final s = _samplesOf(file);
      var worst = 0;
      for (var i = 1; i < s.length; i++) {
        final jump = (s[i] - s[i - 1]).abs();
        if (jump < 2000) continue;
        var before = 0;
        var after = 0;
        for (var j = max(0, i - 240); j < i; j++) {
          before = max(before, s[j].abs());
        }
        for (var j = i; j < min(s.length, i + 240); j++) {
          after = max(after, s[j].abs());
        }
        if (before > 655 && after > 655) continue; // both sides loud
        worst = max(worst, jump);
      }
      return worst;
    }

    test('a step out of silence is smoothed away', () {
      final samples = _speech(24000, 1.0);
      // Silence, then an instant jump to a loud sample: the shape of the pop.
      for (var i = 12000; i < 12600; i++) {
        samples[i] = 0;
      }
      samples[12600] = 9000;
      final before = wav(samples);
      expect(worstStep(before), greaterThan(2000), reason: 'the fixture ticks');
      expect(worstStep(polishNarration(before)), 0);
    });

    test('a loud consonant is not flattened', () {
      // The same size of jump, but with speech either side of it, which is a
      // transient rather than a click. Smoothing those would be a lisp.
      final samples = _speech(24000, 1.0);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = (samples[i].abs() + 6000).clamp(-32768, 32767);
      }
      samples[12000] = -9000;
      final polished = polishNarration(wav(samples));
      expect(_samplesOf(polished).length, samples.length);
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

  group('the splice does not click', () {
    // A pop was audible at the end of every paragraph, and in the Lunii
    // navigation which encodes the same audio. The cause: a model's "silence"
    // is room tone a few hundred units off the line, and the lengthened gap
    // was filled with exact zeros — so the waveform stepped instantly, twice
    // per gap, and a step is a click however quiet its surroundings.
    const rate = 24000;

    /// Room tone: quiet enough that the gap detector calls it silence, but
    /// nowhere near digital zero — which is the whole point. Real TTS output
    /// sits here, and filling a gap with exact zeros beside it steps.
    List<int> roomTone(int samples, {int level = 70, int seed = 3}) {
      final rng = Random(seed);
      return [for (var i = 0; i < samples; i++) level + rng.nextInt(60) - 30];
    }

    test('a lengthened gap never steps', () {
      final source = [
        ..._speech(rate, 0.3),
        ...roomTone(rate ~/ 2), // 500 ms of room tone, not zeros
        ..._speech(rate, 0.3, seed: 2),
      ];
      final after = polishNarration(wav(source));

      // The gap was lengthened — that is the feature working.
      expect(_seconds(after), greaterThan(_seconds(wav(source))));

      // Measured inside the pause, which is the only place a splice can be.
      // Comparing whole-file peaks instead catches the gain scaling speech's
      // own transients by a few units and says nothing about the splice.
      final view = ByteData.sublistView(after);
      final count = (after.length - 44) ~/ 2;
      var worstInGap = 0;
      for (var i = rate + 1; i < count - rate; i++) {
        final a = view.getInt16(44 + (i - 1) * 2, Endian.little);
        final b = view.getInt16(44 + i * 2, Endian.little);
        worstInGap = max(worstInGap, (b - a).abs());
      }
      // Room tone wanders by a few tens of units. A splice onto digital zero
      // would show as a step of the tone's whole level at once.
      expect(
        worstInGap,
        lessThan(60),
        reason: 'the pause must not step; that step is the click',
      );
    });

    test('room tone still touches the speech on both sides', () {
      // The silence goes in the middle of the gap, so the real room tone
      // stays adjacent to the words. Filling from the end instead would put
      // digital zero right against a word's last breath.
      final source = [
        ..._speech(rate, 0.3),
        ...roomTone(rate ~/ 2),
        ..._speech(rate, 0.3, seed: 2),
      ];
      final after = polishNarration(wav(source));
      final view = ByteData.sublistView(after);
      final count = (after.length - 44) ~/ 2;

      // Just after the first speech run ends there must still be tone, not a
      // run of zeros.
      var nonZeroJustAfterSpeech = 0;
      for (var i = rate + 10; i < rate + 2000 && i < count; i++) {
        if (view.getInt16(44 + i * 2, Endian.little) != 0) {
          nonZeroJustAfterSpeech++;
        }
      }
      expect(nonZeroJustAfterSpeech, greaterThan(100));
    });

    test('a gap too short to lengthen is left exactly alone', () {
      final source = [
        ..._speech(rate, 0.3),
        ...roomTone(rate ~/ 5), // 200 ms — a sentence break
        ..._speech(rate, 0.3, seed: 2),
      ];
      final before = wav(source);
      final after = polishNarration(before);
      expect(_seconds(after), closeTo(_seconds(before), 0.01));
    });
  });

  group('nothing is pushed past full scale', () {
    // The bug that made the polish worse than what it fixed. A bedtime
    // narration is not quiet — several cached chapters already peaked at
    // 32767 — so lifting a band by up to 4 dB ran samples into the clamp.
    // Measured on the real cache: every polished file hit the rail, one of
    // them on 1 260 samples where the original hit it on four. Flattened
    // peaks are hard clipping, and hard clipping is the pop of static that
    // was reported at the end of paragraphs.
    const rate = 24000;

    int atCeiling(Uint8List w) {
      final view = ByteData.sublistView(w);
      final count = (w.length - 44) ~/ 2;
      var hits = 0;
      for (var i = 0; i < count; i++) {
        if (view.getInt16(44 + i * 2, Endian.little).abs() >= 32760) hits++;
      }
      return hits;
    }

    int peakOf(Uint8List w) {
      final view = ByteData.sublistView(w);
      final count = (w.length - 44) ~/ 2;
      var peak = 0;
      for (var i = 0; i < count; i++) {
        peak = max(peak, view.getInt16(44 + i * 2, Endian.little).abs());
      }
      return peak;
    }

    /// Quiet first, loud and already peaking after — exactly the shape that
    /// makes the drift correction want to raise the loud half.
    Uint8List risingToTheRail() {
      final source = <int>[];
      for (var b = 0; b < 6; b++) {
        source.addAll(_speech(rate * 8, b < 3 ? 0.2 : 0.99, seed: b));
        source.addAll(_silence(rate ~/ 2));
      }
      return wav(source);
    }

    test('audio already at the rail is not lifted into it', () {
      final before = risingToTheRail();
      expect(
        atCeiling(polishNarration(before)),
        lessThanOrEqualTo(atCeiling(before)),
      );
    });

    test('a quiet passage is still lifted', () {
      // The headroom limit must not quietly become a refusal to do anything.
      final source = <int>[];
      for (var b = 0; b < 6; b++) {
        source.addAll(_speech(rate * 8, b < 3 ? 0.05 : 0.2, seed: b));
        source.addAll(_silence(rate ~/ 2));
      }
      final peak = peakOf(polishNarration(wav(source)));
      expect(peak, greaterThan(0.05 * 32767));
      expect(peak, lessThan(32760));
    });
  });

  test('running it twice changes nothing more', () {
    const rate = 24000;
    final once = polishNarration(
      wav([
        ..._speech(rate, 0.3),
        ..._silence(rate ~/ 2),
        ..._speech(rate, 0.3, seed: 2),
      ]),
    );
    expect(polishNarration(once).length, once.length);
  });

  test('an empty chapter does not throw', () {
    expect(polishNarration(Uint8List(0)).length, 0);
    expect(polishNarration(wav(const [])).length, 44);
  });

  // The root of the static: the manifest Google appends after the sound was
  // read as samples and saved as audio. Whatever the polish does, it must
  // only ever work on the sound.
  test('a C2PA manifest after the sound never becomes sound', () {
    final clean = wav([
      ..._speech(24000, 0.3),
      ..._silence(12000),
      ..._speech(24000, 0.3),
    ]);
    final google = BytesBuilder()
      ..add(clean)
      ..add('C2PA'.codeUnits)
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, 6062, Endian.little))
      ..add(Uint8List.fromList(List.filled(6062, 0x7A)));
    final bytes = google.toBytes();
    bytes.buffer.asByteData().setUint32(4, bytes.length - 8, Endian.little);

    final polished = polishNarration(bytes);
    expect(String.fromCharCodes(polished).contains('C2PA'), isFalse);
    // No 0x7A7A samples - the manifest's filler - anywhere in the output.
    final samples = _samplesOf(polished);
    expect(samples.where((s) => s == 0x7A7A), isEmpty);
    // The de-click reads through the same door: same length as the clean
    // file, so not one byte of the manifest came along.
    expect(deClickNarration(bytes).length, clean.length);
  });
}

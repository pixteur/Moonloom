@TestOn('windows')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/mp3_decoder.dart';
import 'package:moonloom/adapters/audio/mp3_encoder.dart';
import 'package:moonloom/adapters/audio/mp3_frame.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

/// mpglib, through the same DLL as the encoder.
///
/// The pair is what makes an MP3-returning voice sendable: decode to samples,
/// re-encode at what the device plays. So most of these go round the loop
/// rather than checking the decoder alone.
void main() {
  Uint8List tone({
    required int sampleRate,
    required double seconds,
    double hz = 440,
    int channels = 1,
  }) {
    final frames = (sampleRate * seconds).round();
    final samples = Int16List(frames * channels);
    for (var f = 0; f < frames; f++) {
      final v = (sin(2 * pi * hz * f / sampleRate) * 9000).round();
      for (var c = 0; c < channels; c++) {
        samples[f * channels + c] = v;
      }
    }
    return Uint8List.sublistView(samples);
  }

  Uint8List wav({
    int sampleRate = 24000,
    double seconds = 1.0,
    int channels = 1,
  }) => pcmToWav(
    tone(sampleRate: sampleRate, seconds: seconds, channels: channels),
    sampleRate: sampleRate,
    channels: channels,
  );

  test('the decoder is available wherever the encoder is', () {
    expect(canDecodeMp3, canEncodeMp3);
  });

  test('decodes what we encoded, at the rate we encoded it', () {
    final decoded = decodeMp3(wavToLuniiMp3(wav(seconds: 2)));
    expect(decoded.sampleRate, luniiSampleRate);
    expect(decoded.channels, 1);
    // Encoders pad; two seconds in should come back as about two seconds.
    expect(decoded.duration.inMilliseconds, closeTo(2000, 120));
  });

  test('the samples are the sound, not noise', () {
    // A decode that "works" but returns silence or garbage would pass a
    // duration check, so look at the waveform: a 440 Hz tone should come back
    // loud, and near enough the same loudness as it went in.
    final source = decodeWav(wav(seconds: 1));
    final decoded = decodeMp3(wavToLuniiMp3(wav(seconds: 1)));

    double rms(Int16List s) {
      var sum = 0.0;
      for (final v in s) {
        sum += v * v;
      }
      return sqrt(sum / s.length);
    }

    final before = rms(source.samples);
    final after = rms(decoded.samples);
    expect(after, greaterThan(before * 0.7));
    expect(after, lessThan(before * 1.3));
  });

  test('a 24 kHz MP3 round-trips into one the device will play', () {
    // The whole point: this is the OpenAI voice's shape, and it could not be
    // sent to a storyteller until it could be decoded.
    final theirs = _encodeAt(wav(sampleRate: 24000, seconds: 1), 24000);
    expect(Mp3FrameHeader.findFirst(theirs)!.sampleRate, 24000);

    final ours = encodePcmToLuniiMp3(decodeMp3(theirs));
    final header = Mp3FrameHeader.parse(ours)!;
    expect(header.sampleRate, luniiSampleRate);
    expect(header.mode, ChannelMode.mono);
    expect(header.version, MpegVersion.mpeg1);
  });

  test('stereo comes back interleaved', () {
    final stereo = _encodeAt(
      wav(sampleRate: 44100, seconds: 1, channels: 2),
      44100,
      channels: 2,
    );
    final decoded = decodeMp3(stereo);
    expect(decoded.channels, 2);
    expect(decoded.samples.length.isEven, isTrue);
    expect(decoded.duration.inMilliseconds, closeTo(1000, 120));
  });

  group('refuses what it cannot read', () {
    test('nothing at all', () {
      expect(() => decodeMp3(Uint8List(0)), throwsA(isA<Mp3DecodeException>()));
    });

    test('bytes that are not an MP3', () {
      expect(
        () => decodeMp3(Uint8List.fromList(List.filled(4096, 0x41))),
        throwsA(isA<Mp3DecodeException>()),
      );
    });
  });
}

/// Encode at an arbitrary rate, to stand in for a voice that is not ours.
Uint8List _encodeAt(Uint8List wavBytes, int rate, {int channels = 1}) =>
    encodePcmToMp3(
      decodeWav(wavBytes),
      sampleRate: rate,
      bitrateKbps: 64,
      mono: channels == 1,
    );

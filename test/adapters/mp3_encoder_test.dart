@TestOn('windows')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/lame.dart';
import 'package:moonloom/adapters/audio/mp3_encoder.dart';
import 'package:moonloom/adapters/audio/mp3_frame.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

/// Real encodes through the vendored `libmp3lame.dll`. The bar is not "an MP3
/// came out" — it is that **every** frame is MPEG-1 Layer III, 44.1 kHz, mono,
/// which is what `tool/lunii_audio_survey.dart` found on all 1.87M frames of a
/// physical device, with a filled-in LAME tag and no ID3. Checking only the
/// first frame is what hid the device's own audio being VBR, so these walk the
/// whole stream.
///
/// Skipped where the DLL isn't vendored, which is CI.
void main() {
  /// A quiet tone, so the encoder has real signal to chew on rather than
  /// silence it can encode away to nothing.
  Uint8List tone({
    required int sampleRate,
    required double seconds,
    int channels = 1,
  }) {
    final frames = (sampleRate * seconds).round();
    final samples = Int16List(frames * channels);
    for (var f = 0; f < frames; f++) {
      final v = (sin(2 * pi * 440 * f / sampleRate) * 8000).round();
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

  /// Walk the whole stream, header to header, collecting every frame.
  List<Mp3FrameHeader> frames(Uint8List mp3) {
    final found = <Mp3FrameHeader>[];
    var at = 0;
    while (at + 4 <= mp3.length) {
      final header = Mp3FrameHeader.parse(mp3, at);
      if (header == null) break;
      found.add(header);
      at += header.frameLength;
    }
    return found;
  }

  bool contains(Uint8List bytes, String needle) {
    outer:
    for (var i = 0; i + needle.length <= bytes.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle.codeUnitAt(j)) continue outer;
      }
      return true;
    }
    return false;
  }

  test('the vendored DLL loads', () {
    expect(canEncodeMp3, isTrue);
  });

  test('24 kHz mono comes out as the format the device plays', () {
    final header = Mp3FrameHeader.parse(wavToLuniiMp3(wav()))!;
    expect(header.offset, 0, reason: 'no bytes before the audio');
    expect(header.summary, 'MPEG1 L3 44100Hz 128kbps mono');
  });

  test('every frame is that format, not just the first', () {
    final all = frames(wavToLuniiMp3(wav(seconds: 2)));
    expect(all.length, greaterThan(50));
    expect(
      all.map((f) => f.summary).toSet(),
      {'MPEG1 L3 44100Hz 128kbps mono'},
      reason: 'constant bitrate, one format throughout',
    );
  });

  test('the frames account for the whole stream', () {
    final mp3 = wavToLuniiMp3(wav());
    final total = frames(mp3).fold<int>(0, (sum, f) => sum + f.frameLength);
    // Padding aside, walking frame lengths should land on the end of the file:
    // a shortfall means a gap the walk stopped at.
    expect(total, closeTo(mp3.length, 4));
  });

  test('the reserved LAME tag frame is filled in, not left as zeroes', () {
    final mp3 = wavToLuniiMp3(wav());
    final firstFrame = mp3.sublist(0, Mp3FrameHeader.parse(mp3)!.frameLength);
    expect(
      contains(firstFrame, 'Xing') || contains(firstFrame, 'Info'),
      isTrue,
      reason: 'the device\'s own packs all carry one',
    );
    expect(contains(firstFrame, 'LAME'), isTrue);
    expect(
      firstFrame.sublist(4).any((b) => b != 0),
      isTrue,
      reason: 'a frame of zeroes means the backfill never happened',
    );
  });

  test('no ID3 tag, at either end', () {
    final mp3 = wavToLuniiMp3(wav());
    expect(String.fromCharCodes(mp3, 0, 3), isNot('ID3'));
    expect(
      String.fromCharCodes(mp3, mp3.length - 128, mp3.length - 125),
      isNot('TAG'),
    );
  });

  test('duration survives the resample', () {
    final all = frames(wavToLuniiMp3(wav(seconds: 2)));
    // Every frame carries 1152 samples at 44.1 kHz. The Xing frame is silent
    // and the encoder pads the tail, so this lands near 2s, not exactly on it.
    final seconds = all.length * 1152 / 44100;
    expect(seconds, closeTo(2.0, 0.15));
  });

  test('stereo input is downmixed', () {
    final mp3 = wavToLuniiMp3(wav(channels: 2));
    expect(Mp3FrameHeader.parse(mp3)!.mode, ChannelMode.mono);
  });

  test('audio already at 44.1 kHz passes through the same path', () {
    final mp3 = wavToLuniiMp3(wav(sampleRate: 44100));
    expect(Mp3FrameHeader.parse(mp3)!.summary, 'MPEG1 L3 44100Hz 128kbps mono');
  });

  test('a very short clip still produces a playable frame', () {
    final mp3 = wavToLuniiMp3(wav(seconds: 0.02));
    expect(Mp3FrameHeader.parse(mp3), isNotNull);
  });

  test('empty audio is refused rather than encoded to nothing', () {
    expect(
      () => encodePcmToLuniiMp3(
        WavAudio(samples: Int16List(0), sampleRate: 24000, channels: 1),
      ),
      throwsA(isA<LameException>()),
    );
  });
}

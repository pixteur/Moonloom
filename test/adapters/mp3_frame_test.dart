import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/mp3_frame.dart';

/// This header parse is what decides whether a file will play on the
/// storyteller, both when checking the device and when checking our own
/// output, so it is tested against hand-built headers where every field is
/// known.
void main() {
  /// Build a four-byte header. Defaults are what the device wants: MPEG-1
  /// Layer III, 44.1 kHz, 128 kbps, mono.
  Uint8List header({
    int version = 3, // MPEG-1
    int layer = 1, // Layer III
    int bitrateIndex = 9, // 128 kbps
    int rateIndex = 0, // 44100
    int mode = 3, // mono
    bool padded = false,
  }) => Uint8List.fromList([
    0xFF,
    0xE0 | (version << 3) | (layer << 1) | 1,
    (bitrateIndex << 4) | (rateIndex << 2) | (padded ? 2 : 0),
    mode << 6,
  ]);

  test('decodes the format the storyteller wants', () {
    final h = Mp3FrameHeader.parse(header())!;
    expect(h.version, MpegVersion.mpeg1);
    expect(h.layer, 3);
    expect(h.sampleRate, 44100);
    expect(h.bitrateKbps, 128);
    expect(h.mode, ChannelMode.mono);
    expect(h.channels, 1);
    expect(h.summary, 'MPEG1 L3 44100Hz 128kbps mono');
  });

  test('frame length and sample count follow the spec', () {
    // MPEG-1 Layer III: 144 * bitrate / rate = 144 * 128000 / 44100 = 417.9.
    expect(Mp3FrameHeader.parse(header())!.frameLength, 417);
    expect(Mp3FrameHeader.parse(header(padded: true))!.frameLength, 418);
    expect(Mp3FrameHeader.parse(header())!.samplesPerFrame, 1152);
    // MPEG-2 halves both the rate and the samples per frame.
    final v2 = Mp3FrameHeader.parse(header(version: 2, bitrateIndex: 8))!;
    expect(v2.sampleRate, 22050);
    expect(v2.bitrateKbps, 64);
    expect(v2.samplesPerFrame, 576);
  });

  test('stereo modes report two channels', () {
    for (final mode in [0, 1, 2]) {
      expect(Mp3FrameHeader.parse(header(mode: mode))!.channels, 2);
    }
  });

  group('refuses anything that is not a frame header', () {
    test('no sync', () {
      expect(Mp3FrameHeader.parse(Uint8List.fromList([0, 0, 0, 0])), isNull);
    });
    test('reserved version', () {
      expect(Mp3FrameHeader.parse(header(version: 1)), isNull);
    });
    test('reserved layer', () {
      expect(Mp3FrameHeader.parse(header(layer: 0)), isNull);
    });
    test('free-format and invalid bitrates', () {
      expect(Mp3FrameHeader.parse(header(bitrateIndex: 0)), isNull);
      expect(Mp3FrameHeader.parse(header(bitrateIndex: 15)), isNull);
    });
    test('reserved sample rate', () {
      expect(Mp3FrameHeader.parse(header(rateIndex: 3)), isNull);
    });
    test('layers I and II, which nothing here writes', () {
      expect(Mp3FrameHeader.parse(header(layer: 3)), isNull);
      expect(Mp3FrameHeader.parse(header(layer: 2)), isNull);
    });
    test('truncated buffer', () {
      expect(Mp3FrameHeader.parse(header().sublist(0, 3)), isNull);
    });
  });

  group('findFirst', () {
    /// Two back-to-back frames, so a candidate can be confirmed by the one
    /// that follows it.
    Uint8List stream({int lead = 0}) {
      final frame = Uint8List(417)..setRange(0, 4, header());
      return Uint8List.fromList([
        ...List.filled(lead, 0x00),
        ...frame,
        ...frame,
      ]);
    }

    test('finds a frame at the very start', () {
      expect(Mp3FrameHeader.findFirst(stream())!.offset, 0);
    });

    test('skips leading junk', () {
      expect(Mp3FrameHeader.findFirst(stream(lead: 7))!.offset, 7);
    });

    test('skips an ID3v2 tag', () {
      final tag = Uint8List(10 + 300)
        ..setRange(0, 3, 'ID3'.codeUnits)
        ..[3] = 3
        ..[6] = 0
        ..[7] = 0
        ..[8] = 2
        ..[9] = 44; // syncsafe 300
      final bytes = Uint8List.fromList([...tag, ...stream()]);
      expect(Mp3FrameHeader.findFirst(bytes)!.offset, 310);
    });

    test('a lone sync pattern with no frame after it is not a frame', () {
      // A valid-looking header, then nothing that follows on from it.
      final decoy = Uint8List(600)..setRange(0, 4, header());
      decoy.setRange(417, 421, [0x11, 0x22, 0x33, 0x44]);
      expect(Mp3FrameHeader.findFirst(decoy), isNull);
    });

    test('a short buffer holding only one header still counts', () {
      expect(Mp3FrameHeader.findFirst(header())!.offset, 0);
    });

    test('finds nothing in noise', () {
      expect(Mp3FrameHeader.findFirst(Uint8List(500)), isNull);
    });
  });
}

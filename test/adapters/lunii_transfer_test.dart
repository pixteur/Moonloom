import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moonloom/adapters/audio/mp3_encoder.dart';
import 'package:moonloom/adapters/audio/mp3_frame.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/lunii/device_writer.dart';
import 'package:moonloom/adapters/lunii/lunii_cipher.dart';
import 'package:moonloom/adapters/lunii/lunii_transfer.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

/// The seam between a story's cached narration and a pack on a device.
///
/// Everything either side of it is covered — the encoder, the pack builder,
/// the writer — but the joining up was not, and that is where the decisions
/// live: which chapters go, what happens to a voice whose audio cannot be
/// re-encoded, and what the grown-up is told afterwards.
///
/// [buildAndWritePack] is the worker [sendStoryToLunii] runs in an isolate.
/// Testing it directly keeps these synchronous and lets them look at the
/// files that land.
void main() {
  late Directory temp;
  late String root;

  /// A storyteller-shaped directory. Arbitrary `.md` bytes are enough: the key
  /// derivation just deciphers them, and a pack written with the result reads
  /// back with it.
  void makeDevice() {
    root = temp.path;
    final md = Uint8List(0x200);
    for (var i = 0; i < md.length; i++) {
      md[i] = (i * 17 + 3) & 0xFF;
    }
    File('$root/.md').writeAsBytesSync(md);
    File('$root/.pi').writeAsBytesSync(Uint8List(0));
    File('$root/.cfg').writeAsStringSync('volume=3\n');
    Directory('$root/.content').createSync();
  }

  /// A cached chunk: half a second of tone, wrapped as WAV and compressed the
  /// way the audio cache stores it.
  Uint8List wavChunk({double seconds = 0.5, int rate = 24000}) {
    final frames = (rate * seconds).round();
    final samples = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      samples[i] = ((i % 50) - 25) * 300;
    }
    return compressAudio(
      pcmToWav(Uint8List.sublistView(samples), sampleRate: rate),
    );
  }

  /// A cached chunk that is already MP3, as the ElevenLabs and OpenAI voices
  /// return — either at what the device plays, or at 24 kHz like OpenAI.
  ///
  /// Really encoded, not hand-built. Frame headers with no payload behind them
  /// parse perfectly well and decode to nothing at all, so a fixture made that
  /// way tests the header reader and never reaches the decoder.
  Uint8List mp3Chunk({bool deviceReady = true}) {
    final rate = deviceReady ? 44100 : 24000;
    final samples = Int16List(rate ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (sin(2 * pi * 440 * i / rate) * 8000).round();
    }
    return compressAudio(
      encodePcmToMp3(
        WavAudio(samples: samples, sampleRate: rate, channels: 1),
        sampleRate: rate,
        bitrateKbps: deviceReady ? luniiBitrateKbps : 64,
        mono: true,
      ),
    );
  }

  LuniiTransferRequest request({
    required List<List<Uint8List>> chapters,
    int skipped = 0,
    LuniiCoverMotif motif = LuniiCoverMotif.nightSky,
    String? worldName,
    Uint8List? coverImage,
  }) => LuniiTransferRequest(
    drive: root,
    backupDirectory: '${temp.path}/backup',
    title: "Ashi's adventure",
    chapterChunks: chapters,
    skipped: skipped,
    motif: motif,
    worldName: worldName,
    coverImage: coverImage,
  );

  /// A drawn picture, as PNG: what the image model hands back. Two colours in
  /// a shape nothing procedural would make, so "this one reached the device"
  /// is answerable from the bytes.
  Uint8List drawnPng({int red = 230}) {
    final image = img.Image(width: 1024, height: 768);
    for (var y = 0; y < 768; y++) {
      for (var x = 0; x < 1024; x++) {
        image.setPixelRgb(x, y, y < 384 ? red : 20, 60, 140);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  /// The one image file in a written pack.
  Uint8List coverOf(String packName) => File(
    Directory(
      '$root/.content/$packName/rf/000',
    ).listSync().whereType<File>().single.path,
  ).readAsBytesSync();

  setUp(() => temp = Directory.systemTemp.createTempSync('lunii_transfer'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('what the grown-up is told', () {
    test('names the chapters, the size and the drive', () {
      const transfer = LuniiTransfer(
        packName: 'E7E036FC',
        chapters: 6,
        skipped: 0,
        bytes: 23524892,
        drive: 'F:',
      );
      expect(
        transfer.summary,
        '6 chapters (22.4 MB) sent to the storyteller on F:',
      );
    });

    test('says when chapters were left behind', () {
      const transfer = LuniiTransfer(
        packName: 'A1B2C3D4',
        chapters: 1,
        skipped: 2,
        bytes: 1048576,
        drive: 'F:',
      );
      expect(transfer.summary, contains('1 chapter ('));
      expect(transfer.summary, contains('2 not downloaded yet, left out'));
    });
  });

  group('refusals', () {
    test('nothing to send is refused before the device is touched', () {
      makeDevice();
      expect(
        () => buildAndWritePack(request(chapters: const [])),
        throwsA(isA<LuniiDeviceException>()),
      );
      expect(File('$root/.pi').lengthSync(), 0);
    });

    test('a drive that is not a storyteller is refused', () {
      root = temp.path; // no .md, .pi or .content
      expect(
        () => buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
          ),
        ),
        throwsA(isA<LuniiDeviceException>()),
      );
    });
  });

  group(
    'voices that hand back MP3',
    () {
      setUp(makeDevice);

      test('a chapter already in the device\'s format still goes', () {
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [mp3Chunk(), mp3Chunk()],
            ],
          ),
        );
        expect(transfer.chapters, 1);
        final sound = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().single;
        expect(
          Mp3FrameHeader.parse(luniiPlain(sound))?.summary,
          'MPEG1 L3 ${luniiSampleRate}Hz ${luniiBitrateKbps}kbps mono',
        );
      });

      test('a chapter at another rate is re-encoded, not refused', () {
        // This is the OpenAI voice's shape. Before the decoder existed it was
        // turned away at this point; now it goes through samples like the rest.
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [mp3Chunk(deviceReady: false)],
            ],
          ),
        );
        final sound = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().single;
        final header = Mp3FrameHeader.parse(luniiPlain(sound))!;
        expect(header.sampleRate, luniiSampleRate);
        expect(header.mode, ChannelMode.mono);
      });
    },
    skip: canEncodeMp3 ? false : 'needs the vendored LAME (Windows)',
  );

  group(
    'building from cached WAV',
    () {
      setUp(makeDevice);

      test('each chapter becomes one sound the device will play', () {
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [wavChunk(), wavChunk()],
              [wavChunk()],
              [wavChunk(), wavChunk(), wavChunk()],
            ],
          ),
        );
        expect(transfer.chapters, 3);
        expect(transfer.drive, root);

        final sounds = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().toList();
        expect(sounds.length, 3, reason: 'one per chapter, chunks joined');
        for (final sound in sounds) {
          final plain = luniiPlain(sound);
          expect(
            Mp3FrameHeader.parse(plain)?.summary,
            'MPEG1 L3 ${luniiSampleRate}Hz ${luniiBitrateKbps}kbps mono',
          );
        }
      });

      test('the pack lands in .pi and nothing else on the device changes', () {
        final before = File('$root/.cfg').readAsStringSync();
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
          ),
        );
        final device = LuniiDevice.open(root);
        expect(device.packDirectories, [transfer.packName]);
        expect(File('$root/.cfg').readAsStringSync(), before);
        expect(File('${temp.path}/backup/pi.bak').existsSync(), isTrue);
      });

      test('the cover motif picks the picture', () {
        final velo = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            motif: LuniiCoverMotif.velo,
          ),
        );
        final image = File(
          Directory(
            '$root/.content/${velo.packName}/rf/000',
          ).listSync().whereType<File>().single.path,
        );
        // Both motifs are 320×240 in sixteen colours, so the check that they
        // differ is the bytes themselves.
        makeDevice();
        final sky = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
          ),
        );
        final other = File(
          Directory(
            '$root/.content/${sky.packName}/rf/000',
          ).listSync().whereType<File>().single.path,
        );
        expect(image.readAsBytesSync(), isNot(other.readAsBytesSync()));
      });

      // Before this, the device picture was seeded on the world's name, so
      // every episode of one world was the same picture on the shelf. A
      // picture drawn for *this* story has to win.
      test('a drawn picture beats the world picture', () {
        final drawn = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
            coverImage: drawnPng(),
          ),
        );
        final withPicture = coverOf(drawn.packName);

        makeDevice();
        final without = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
          ),
        );
        expect(withPicture, isNot(coverOf(without.packName)));
      });

      test('two stories in one world get two pictures', () {
        final first = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
            coverImage: drawnPng(red: 230),
          ),
        );
        final one = coverOf(first.packName);

        makeDevice();
        final second = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
            coverImage: drawnPng(red: 40),
          ),
        );
        expect(one, isNot(coverOf(second.packName)));
      });

      // The fallback is the point of returning null from the reduction rather
      // than throwing: a picture that will not decode costs a nicer picture,
      // not a transfer whose audio was all present.
      test('a picture that will not decode falls back to the world', () {
        final broken = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
            coverImage: Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
          ),
        );
        final fallback = coverOf(broken.packName);

        makeDevice();
        final plain = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            worldName: "Pip's Adventures",
          ),
        );
        expect(fallback, coverOf(plain.packName));
      });

      test('dead air in a chunk does not reach the device', () {
        // Half a second of tone then ten seconds of nothing, the shape a
        // glitched chapter came back in. Sixty seconds of real audio would be
        // far bigger than what a trimmed one encodes to.
        final glitched = compressAudio(
          pcmToWav(
            Uint8List.sublistView(
              Int16List(24000 * 11)
                ..setRange(0, 12000, List.filled(12000, 6000)),
            ),
            sampleRate: 24000,
          ),
        );
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [glitched],
            ],
          ),
        );
        final sound = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().single;
        // One second at 128 kbps is about 16 kB; eleven would be about 176.
        expect(sound.lengthSync(), lessThan(40 * 1024));
      });
    },
    skip: canEncodeMp3 ? false : 'needs the vendored LAME (Windows)',
  );
}

/// An asset as it sits on the device is ciphered over its first sector, so it
/// has to be deciphered before it looks like an MP3 again.
Uint8List luniiPlain(File file) =>
    luniiDecipher(file.readAsBytesSync(), luniiGenericKey);

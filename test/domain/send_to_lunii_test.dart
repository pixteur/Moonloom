import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/audio/mp3_encoder.dart';
import 'package:moonloom/adapters/lunii/device_writer.dart';
import 'package:moonloom/adapters/tts/audio_cache.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/sleepy_service.dart';

import '../support/in_memory_storage_repo.dart';

class _MemCache implements AudioCache {
  final Map<String, Uint8List> _m = {};
  @override
  Future<Uint8List?> get(String key) async => _m[key];
  @override
  Future<void> put(String key, Uint8List bytes) async => _m[key] = bytes;
}

/// `SleepyService.sendToLunii`, from the library down to files on a device.
///
/// What this covers that the layers below do not: which chapters are chosen,
/// what happens when one is only half downloaded, and what the caller is told.
/// Cache keys come from `chapterAudioKeys` here as they do in the service, so
/// a change to how playback keys its chunks fails this rather than silently
/// sending the wrong audio.
void main() {
  late Directory temp;
  late String root;

  void makeDevice() {
    root = '${temp.path}/device';
    Directory('$root/.content').createSync(recursive: true);
    final md = Uint8List(0x200);
    for (var i = 0; i < md.length; i++) {
      md[i] = (i * 23 + 5) & 0xFF;
    }
    File('$root/.md').writeAsBytesSync(md);
    File('$root/.pi').writeAsBytesSync(Uint8List(0));
  }

  Uint8List chunkAudio() {
    final samples = Int16List(12000);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = ((i % 40) - 20) * 400;
    }
    return compressAudio(
      pcmToWav(Uint8List.sublistView(samples), sampleRate: 24000),
    );
  }

  const voice = 'gemini/Aoede';
  const language = 'en';

  Beat beat(int seq, String text) => Beat(
    id: 'b$seq',
    seriesId: 's1',
    childId: 'kid',
    seq: seq,
    intent: StoryIntent.continued,
    text: text,
    summary: 'ch$seq',
    isFinal: false,
  );

  const series = Series(
    id: 's1',
    childId: 'kid',
    title: "Ashi's adventure",
    theme: StoryTheme.adventure,
    seedSummary: 'A bicycle, a forest.',
  );

  /// Seed a story and cache narration for whichever chapters are named.
  Future<SleepyService> library({
    required List<String> chapters,
    required Set<int> cached,
  }) async {
    final repo = InMemoryStorageRepo();
    final cache = _MemCache();
    await repo.saveSeries(series);
    for (var i = 0; i < chapters.length; i++) {
      final b = beat(i, chapters[i]);
      await repo.saveBeat(b);
      if (!cached.contains(i)) continue;
      // The one supported way to know where a chapter's audio lives.
      for (final key in chapterAudioKeys(
        voiceSignature: voice,
        language: language,
        text: b.text,
        notes: b.narration,
      )) {
        await cache.put(key, chunkAudio());
      }
    }
    return SleepyService(repo, cache);
  }

  setUp(() => temp = Directory.systemTemp.createTempSync('send_to_lunii'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'refuses when no storyteller is plugged in',
    () async {
      final service = await library(chapters: ['One.'], cached: {0});
      await expectLater(
        service.sendToLunii(
          series,
          language: language,
          voiceSignature: voice,
          backupDirectory: '${temp.path}/backup',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'says what to do',
            contains('Plug the Lunii in'),
          ),
        ),
      );
    },
    skip: findLuniiDevices().isEmpty ? false : 'a real device is attached',
  );

  test('refuses when nothing is downloaded', () async {
    makeDevice();
    final service = await library(chapters: ['One.', 'Two.'], cached: const {});
    await expectLater(
      service.sendToLunii(
        series,
        language: language,
        voiceSignature: voice,
        drive: root,
        backupDirectory: '${temp.path}/backup',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'says what to do',
          contains('play or download'),
        ),
      ),
    );
  });

  group(
    'with an encoder',
    () {
      setUp(makeDevice);

      test('sends every downloaded chapter', () async {
        final service = await library(
          chapters: ['One upon a time.', 'Then the forest.', 'And home.'],
          cached: {0, 1, 2},
        );
        final result = await service.sendToLunii(
          series,
          language: language,
          voiceSignature: voice,
          drive: root,
          backupDirectory: '${temp.path}/backup',
        );
        expect(result.chapters, 3);
        expect(result.skipped, 0);
        expect(result.drive, root);
        expect(LuniiDevice.open(root).packDirectories, [result.packName]);
        expect(
          Directory(
            '$root/.content/${result.packName}/sf/000',
          ).listSync().length,
          3,
        );
      });

      test('leaves a half-downloaded chapter out, and counts it', () async {
        // The middle chapter has no narration. Sending it half-finished would be
        // a story that stops mid-sentence, so it is dropped and reported.
        final service = await library(
          chapters: ['One upon a time.', 'Then the forest.', 'And home.'],
          cached: {0, 2},
        );
        final result = await service.sendToLunii(
          series,
          language: language,
          voiceSignature: voice,
          drive: root,
          backupDirectory: '${temp.path}/backup',
        );
        expect(result.chapters, 2);
        expect(result.skipped, 1);
        expect(result.summary, contains('1 not downloaded yet, left out'));
      });

      test('the backup is taken where it was asked for', () async {
        final service = await library(chapters: ['One.'], cached: {0});
        await service.sendToLunii(
          series,
          language: language,
          voiceSignature: voice,
          drive: root,
          backupDirectory: '${temp.path}/backup',
        );
        expect(File('${temp.path}/backup/pi.bak').existsSync(), isTrue);
        expect(File('${temp.path}/backup/md.bak').existsSync(), isTrue);
      });
    },
    skip: canEncodeMp3 ? false : 'needs the vendored LAME (Windows)',
  );
}

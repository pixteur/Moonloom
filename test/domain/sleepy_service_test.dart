import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/audio_cache.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';
import 'package:moonloom/domain/sleepy_service.dart';

import '../support/in_memory_storage_repo.dart';

/// In-memory AudioCache for tests.
class _MemCache implements AudioCache {
  final Map<String, Uint8List> _m = {};
  @override
  Future<Uint8List?> get(String key) async => _m[key];
  @override
  Future<void> put(String key, Uint8List bytes) async => _m[key] = bytes;
}

void main() {
  test(
    '.sleepy export → import round-trips story, world, cast, and audio',
    () async {
      final source = InMemoryStorageRepo();
      final cache = _MemCache();
      const voiceSig = 'gemini/Aoede';
      const lang = 'en';

      // Seed a world + character + a 2-chapter episode, with audio for ch0.
      const world = World(
        id: 'w1',
        childId: 'kid',
        name: 'Splat the Cat',
        premise: 'A curious black cat.',
        theme: StoryTheme.adventure,
      );
      await source.saveWorld(world);
      await source.saveCharacter(
        const StoryCharacter(
          id: 'c1',
          worldId: 'w1',
          name: 'Splat',
          description: 'a big black cat',
        ),
      );
      const series = Series(
        id: 's1',
        childId: 'kid',
        worldId: 'w1',
        title: 'Splat on the Moon',
        theme: StoryTheme.adventure,
        seedSummary: 'A moon trip.',
      );
      await source.saveSeries(series);
      await source.saveBeat(
        const Beat(
          id: 'b0',
          seriesId: 's1',
          childId: 'kid',
          seq: 0,
          intent: StoryIntent.dice,
          text: 'Splat looked up at the moon.',
          summary: 'ch0',
          isFinal: false,
        ),
      );
      await source.saveBeat(
        const Beat(
          id: 'b1',
          seriesId: 's1',
          childId: 'kid',
          seq: 1,
          intent: StoryIntent.continued,
          text: 'And drifted gently to sleep.',
          summary: 'ch1',
          isFinal: true,
        ),
      );
      final audio = Uint8List.fromList(List.filled(200, 7));
      await cache.put(
        audioCacheKey('$voiceSig|$lang|Splat looked up at the moon.'),
        audio,
      );

      final exporter = SleepyService(source, cache);
      final bytes = await exporter.exportBytes(
        series,
        language: lang,
        voiceSignature: voiceSig,
      );
      expect(bytes, isNotEmpty);

      // Import into a fresh repo + cache (a different device/child).
      final dest = InMemoryStorageRepo();
      final destCache = _MemCache();
      final importer = SleepyService(dest, destCache);
      final imported = await importer.importBytes(bytes, 'kid2');

      expect(imported.title, 'Splat on the Moon');
      expect(imported.worldId, isNotNull);

      final worlds = await dest.loadWorlds('kid2');
      expect(worlds.single.name, 'Splat the Cat');
      final cast = await dest.loadCharacters(worlds.single.id);
      expect(cast.single.name, 'Splat');

      final beats = await dest.loadBeats(imported.id);
      expect(beats.map((b) => b.text), [
        'Splat looked up at the moon.',
        'And drifted gently to sleep.',
      ]);
      expect(beats.last.isFinal, isTrue);

      // Audio for ch0 was restored under the exporter's voice key.
      final restored = await destCache.get(
        audioCacheKey('$voiceSig|$lang|Splat looked up at the moon.'),
      );
      expect(restored, audio);
    },
  );

  test('text-only export omits audio (recipient rebuilds voice)', () async {
    final repo = InMemoryStorageRepo();
    final cache = _MemCache();
    const series = Series(
      id: 's1',
      childId: 'kid',
      title: 'Quiet Night',
      theme: StoryTheme.cozy,
    );
    await repo.saveSeries(series);
    await repo.saveBeat(
      const Beat(
        id: 'b0',
        seriesId: 's1',
        childId: 'kid',
        seq: 0,
        intent: StoryIntent.dice,
        text: 'The moon was bright.',
        summary: 'ch0',
        isFinal: true,
      ),
    );
    await cache.put(
      audioCacheKey('gemini/Aoede|en|The moon was bright.'),
      Uint8List.fromList(List.filled(100, 1)),
    );

    final svc = SleepyService(repo, cache);
    final bytes = await svc.exportBytes(
      series,
      language: 'en',
      voiceSignature: 'gemini/Aoede',
      includeAudio: false,
    );

    // Import into a fresh repo/cache: chapter text arrives, but NO audio.
    final dest = InMemoryStorageRepo();
    final destCache = _MemCache();
    final imported = await SleepyService(
      dest,
      destCache,
    ).importBytes(bytes, 'kid2');
    final beats = await dest.loadBeats(imported.id);
    expect(beats.single.text, 'The moon was bright.');
    expect(
      await destCache.get(
        audioCacheKey('gemini/Aoede|en|The moon was bright.'),
      ),
      isNull,
    );
  });
}

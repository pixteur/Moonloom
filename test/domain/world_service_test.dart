import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/world_service.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  late InMemoryStorageRepo repo;
  late WorldService worlds;

  const series = Series(
    id: 's1',
    childId: 'c1',
    title: 'Obsidian Stone',
    theme: StoryTheme.adventure,
    extraThemes: [StoryTheme.nature],
    storyBible: 'Bob and Leo found a glowing stone in the Luminous Forest.',
  );

  Beat beat(int seq, List<String> characters) => Beat(
    id: 'b$seq',
    seriesId: series.id,
    childId: 'c1',
    seq: seq,
    intent: StoryIntent.dice,
    text: 'chapter $seq',
    summary: 'recap $seq',
    rating: AgeRating.tiny,
    characters: characters,
  );

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveSeries(series);
    worlds = WorldService(repo);
  });

  test('a standalone story becomes a world it now belongs to', () async {
    await repo.saveBeat(beat(0, ['Bob', 'Leo']));
    await repo.saveBeat(beat(1, ['Bob', 'Leo', 'a passing badger']));

    final world = await worlds.fromSeries(series);

    expect(world.name, 'Obsidian Stone');
    expect(world.theme, StoryTheme.adventure);
    expect(world.extraThemes, [StoryTheme.nature]);
    expect(world.premise, contains('Luminous Forest'));
    // The story is now episode one of its own world.
    final moved = await repo.loadSeriesById(series.id);
    expect(moved!.worldId, world.id);
  });

  test('the recurring cast is saved, walk-ons rank below them', () async {
    await repo.saveBeat(beat(0, ['Bob', 'Leo']));
    await repo.saveBeat(beat(1, ['Bob', 'Leo', 'a passing badger']));

    final world = await worlds.fromSeries(series);
    final cast = (await repo.loadCharacters(world.id)).map((c) => c.name);
    expect(cast.take(2), ['Bob', 'Leo']);
    // Nobody is queued for an introduction — they're already in the story.
    expect(
      (await repo.loadWorldById(world.id))!.pendingCastChanges.isEmpty,
      isTrue,
    );
  });

  test(
    'a custom world name wins, a blank one falls back to the title',
    () async {
      final named = await worlds.fromSeries(series, name: '  Bob and Leo  ');
      expect(named.name, 'Bob and Leo');

      final blank = await worlds.fromSeries(series, name: '   ');
      expect(blank.name, 'Obsidian Stone');
    },
  );

  test('a story with no chapters still converts', () async {
    final world = await worlds.fromSeries(
      const Series(
        id: 's2',
        childId: 'c1',
        title: 'Untold',
        theme: StoryTheme.cozy,
      ),
    );
    expect(world.premise, 'The world of "Untold".');
    expect(await repo.loadCharacters(world.id), isEmpty);
  });
}

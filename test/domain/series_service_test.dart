import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/series_service.dart';
import 'package:moonloom/domain/twist_deck.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  group('SeriesService', () {
    late InMemoryStorageRepo repo;
    late SeriesService service;

    setUp(() {
      repo = InMemoryStorageRepo();
      service = SeriesService(repo);
    });

    test('create persists and lists only active series', () async {
      final s = await service.create(
        childId: 'c1',
        title: 'Cloud Pirates',
        theme: StoryTheme.adventure,
        heroMode: HeroMode.childAsHero,
      );
      expect(s.id, isNotEmpty);
      expect(await service.forChild('c1'), hasLength(1));

      await service.archive(s);
      expect(await service.forChild('c1'), isEmpty);
      expect(await service.archived('c1'), hasLength(1));
    });

    test('branch copies flavour and records the fork point', () async {
      final base = await service.create(
        childId: 'c1',
        title: 'Cloud Pirates',
        theme: StoryTheme.adventure,
        heroName: 'Captain Bramble',
        heroMode: HeroMode.namedHero,
        seedSummary: 'A sky saga.',
      );
      final branched = await service.branch(
        from: base,
        title: 'Cloud Pirates: Side Quest',
        fromBeatId: 'beat-42',
      );
      expect(branched.theme, StoryTheme.adventure);
      expect(branched.heroName, 'Captain Bramble');
      expect(branched.branchedFromBeatId, 'beat-42');
      expect(await service.forChild('c1'), hasLength(2));
    });
  });

  group('TwistDeck', () {
    const deck = TwistDeck();

    test('offers six option cards', () {
      expect(deck.options(), hasLength(6));
    });

    test('roll is deterministic with a seeded Random', () {
      final t1 = deck.roll(Random(1));
      final t2 = deck.roll(Random(1));
      expect(t1.id, t2.id);
    });

    test('byId finds a known twist', () {
      expect(deck.byId('mystery_door')?.label, isNotNull);
      expect(deck.byId('nope'), isNull);
    });
  });
  group('setLanguages', () {
    Future<Series> saved(InMemoryStorageRepo repo, Series s) async {
      await repo.saveSeries(s);
      return s;
    }

    test('a story can change the language it is told in', () async {
      final repo = InMemoryStorageRepo();
      final service = SeriesService(repo);
      final story = await saved(
        repo,
        const Series(
          id: 's1',
          childId: 'c1',
          title: 'Leo and Bolt',
          theme: StoryTheme.cozy,
        ),
      );

      final updated = await service.setLanguages(
        story,
        baseLanguage: 'fr',
        bilingualEnabled: true,
        secondaryLanguage: 'en',
        bilingualBlend: BilingualBlend.alternating,
      );

      expect(updated.baseLanguage, 'fr');
      expect(languageFor(updated, 'en'), 'fr');
      expect((await repo.loadSeriesById('s1'))!.secondaryLanguage, 'en');
    });

    test('turning bilingual off clears the second language', () async {
      // The reason this is not a copyWith: a copyWith that reads null as
      // "leave it alone" cannot clear a field, and a story left holding a
      // second language it no longer uses would still be prompted for it.
      final repo = InMemoryStorageRepo();
      final service = SeriesService(repo);
      final story = await saved(
        repo,
        const Series(
          id: 's2',
          childId: 'c1',
          title: 'Leo and Bolt',
          theme: StoryTheme.cozy,
          baseLanguage: 'fr',
          bilingualEnabled: true,
          secondaryLanguage: 'en',
          bilingualBlend: BilingualBlend.alternating,
        ),
      );

      final updated = await service.setLanguages(
        story,
        baseLanguage: 'fr',
        bilingualEnabled: false,
        secondaryLanguage: 'en',
        bilingualBlend: BilingualBlend.alternating,
      );

      expect(updated.bilingualEnabled, isFalse);
      expect(updated.secondaryLanguage, isNull);
      expect(updated.bilingualBlend, isNull);
    });

    test('everything else about the story is left alone', () async {
      final repo = InMemoryStorageRepo();
      final story = await saved(
        repo,
        const Series(
          id: 's3',
          childId: 'c1',
          title: 'Leo and Bolt',
          theme: StoryTheme.adventure,
          extraThemes: [StoryTheme.technical],
          heroMode: HeroMode.namedHero,
          heroName: 'Shadow',
          storyBible: 'They found a stone.',
          lastReadSeq: 3,
        ),
      );

      final updated = await SeriesService(repo).setLanguages(
        story,
        baseLanguage: 'es',
        bilingualEnabled: false,
        secondaryLanguage: null,
        bilingualBlend: null,
      );

      expect(updated.title, 'Leo and Bolt');
      expect(updated.extraThemes, [StoryTheme.technical]);
      expect(updated.heroName, 'Shadow');
      expect(updated.storyBible, 'They found a stone.');
      expect(updated.lastReadSeq, 3);
    });
  });
}

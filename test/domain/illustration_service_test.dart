import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/images/picture_store.dart';
import 'package:moonloom/adapters/images/story_illustrator.dart';
import 'package:moonloom/domain/illustration_service.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/story_image.dart';
import 'package:moonloom/domain/models/world.dart';

import '../support/in_memory_storage_repo.dart';

/// Records what it was asked to draw, and with which references.
class _FakeIllustrator implements StoryIllustrator {
  final prompts = <String>[];
  final referenceCounts = <int>[];
  int failuresLeft = 0;

  @override
  Future<DrawnPicture> draw(
    String prompt, {
    StoryImageKind kind = StoryImageKind.chapter,
    int? seed,
    List<Uint8List> references = const [],
  }) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('busy');
    }
    prompts.add(prompt);
    referenceCounts.add(references.length);
    return DrawnPicture(
      // Distinct bytes per call so a store can tell them apart.
      bytes: Uint8List.fromList(List.filled(8, prompts.length)),
      prompt: prompt,
      model: 'fake',
      size: '2K',
      aspect: GeminiIllustrator.aspectFor(kind),
    );
  }
}

class _MemoryPictures implements PictureStore {
  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> read(String key) async => files[key];
  @override
  Future<bool> has(String key) async => files.containsKey(key);
  @override
  Future<void> write(String key, Uint8List bytes) async => files[key] = bytes;
  @override
  Future<File> fileFor(String key) async =>
      throw UnsupportedError('not needed in tests');
}

Beat beat(
  String id,
  int seq, {
  String characters = 'Pip',
  String summary = 'Pip finds a knot.',
}) => Beat(
  id: id,
  seriesId: 's1',
  childId: 'c1',
  seq: seq,
  intent: StoryIntent.continued,
  text: 'Some words.',
  summary: summary,
  title: 'Chapter $seq',
  rating: AgeRating.tiny,
  setting: 'a shallow reef',
  characters: characters.split(','),
);

void main() {
  late InMemoryStorageRepo repo;
  late _FakeIllustrator illustrator;
  late _MemoryPictures pictures;
  late IllustrationService service;

  const series = Series(
    id: 's1',
    childId: 'c1',
    title: 'The Ancient Sea Knot',
    theme: StoryTheme.cozy,
  );
  const world = World(
    id: 'w1',
    childId: 'c1',
    name: "Pip's Adventures",
    styleGuide: 'Soft watercolour washes in honey gold and sage green.',
  );

  setUp(() {
    repo = InMemoryStorageRepo();
    illustrator = _FakeIllustrator();
    pictures = _MemoryPictures();
    service = IllustrationService(
      illustrator: illustrator,
      pictures: pictures,
      repo: repo,
    );
  });

  group('a chapter has one picture', () {
    // Re-illustrating a story — to recover a cover lost to a busy server, say
    // — used to leave the first attempt's rows behind, pointing at the same
    // files, and the reader picked one of them at random.
    test('drawing twice replaces rather than accumulating', () async {
      final beats = [beat('b1', 0), beat('b2', 1), beat('b3', 2)];
      await service.illustrate(series: series, beats: beats, world: world);
      final first = await repo.loadImages('s1');

      await service.illustrate(series: series, beats: beats, world: world);
      final second = await repo.loadImages('s1');

      expect(second, hasLength(first.length));
      expect(
        second.map((i) => '${i.kind}|${i.beatId}').toSet(),
        hasLength(second.length),
        reason: 'one picture per slot',
      );
    });

    test('a cover replaces a cover, not a chapter picture', () async {
      final beats = [beat('b1', 0), beat('b2', 1), beat('b3', 2)];
      await service.illustrate(series: series, beats: beats, world: world);
      final before = await repo.loadImages('s1');
      final chapters = before
          .where((i) => i.kind == StoryImageKind.chapter)
          .length;

      await service.drawOne(
        series: series,
        beat: beats.first,
        kind: StoryImageKind.cover,
      );
      final after = await repo.loadImages('s1');
      expect(after.where((i) => i.kind == StoryImageKind.cover), hasLength(1));
      expect(
        after.where((i) => i.kind == StoryImageKind.chapter),
        hasLength(chapters),
      );
    });
  });

  group('the world is drawn in one hand', () {
    test('the style guide appears verbatim in every prompt', () async {
      await service.illustrate(
        series: series,
        beats: [beat('b1', 0), beat('b2', 1), beat('b3', 2)],
        world: world,
      );
      expect(illustrator.prompts, isNotEmpty);
      for (final prompt in illustrator.prompts) {
        expect(prompt, contains(world.styleGuide));
      }
    });

    test('a world without one still gets a house style', () async {
      const plain = World(id: 'w1', childId: 'c1', name: 'Somewhere');
      await service.illustrate(
        series: series,
        beats: [beat('b1', 0)],
        world: plain,
      );
      expect(illustrator.prompts.first, contains('picture-book'));
    });
  });

  group('character sheets', () {
    test('a sheet is drawn once and reused', () async {
      const pip = StoryCharacter(id: 'ch1', worldId: 'w1', name: 'Pip');
      await repo.saveCharacter(pip);

      await service.ensureSheets(world, [pip]);
      final afterFirst = illustrator.prompts.length;
      final saved = (await repo.loadCharacters('w1')).single;
      expect(saved.sheetFileKey, isNotEmpty);

      // Second time round it already exists, so nothing is drawn.
      await service.ensureSheets(world, [saved]);
      expect(illustrator.prompts, hasLength(afterFirst));
    });

    test(
      'only the characters a scene mentions are sent as references',
      () async {
        const pip = StoryCharacter(id: 'ch1', worldId: 'w1', name: 'Pip');
        const coral = StoryCharacter(id: 'ch2', worldId: 'w1', name: 'Coral');
        await repo.saveCharacter(pip);
        await repo.saveCharacter(coral);
        final sheets = await service.ensureSheets(world, [pip, coral]);
        illustrator.referenceCounts.clear();

        await service.drawOne(
          series: series,
          beat: beat('b1', 0, characters: 'Pip'),
          kind: StoryImageKind.chapter,
          sheets: sheets,
        );
        expect(illustrator.referenceCounts.single, 1);

        illustrator.referenceCounts.clear();
        await service.drawOne(
          series: series,
          beat: beat('b2', 1, characters: 'Pip,Coral'),
          kind: StoryImageKind.chapter,
          sheets: sheets,
        );
        expect(illustrator.referenceCounts.single, 2);
      },
    );

    test('a scene mentioning nobody carries no references', () async {
      const pip = StoryCharacter(id: 'ch1', worldId: 'w1', name: 'Pip');
      await repo.saveCharacter(pip);
      final sheets = await service.ensureSheets(world, [pip]);
      illustrator.referenceCounts.clear();

      await service.drawOne(
        series: series,
        beat: beat(
          'b1',
          0,
          characters: 'a passing gull',
          summary: 'A gull wheels over the water.',
        ),
        kind: StoryImageKind.chapter,
        sheets: sheets,
      );
      expect(illustrator.referenceCounts.single, 0);
    });
  });

  group("the storyteller's portrait", () {
    // A pack gets re-sent — a device wiped, a chapter added. Drawing again
    // would cost another picture and, worse, change the face on the shelf.
    test('drawn once and then reused', () async {
      final beats = [beat('b1', 0), beat('b2', 1)];
      final first = await service.ensureLuniiPortrait(
        series: series,
        beats: beats,
        world: world,
      );
      final drawnSoFar = illustrator.prompts.length;

      final second = await service.ensureLuniiPortrait(
        series: series,
        beats: beats,
        world: world,
      );
      expect(illustrator.prompts, hasLength(drawnSoFar));
      expect(second!.$1.fileKey, first!.$1.fileKey);
      expect(
        (await repo.loadImages(
          's1',
        )).where((i) => i.kind == StoryImageKind.lunii),
        hasLength(1),
      );
    });

    // A row whose file has gone is not a picture. A cleared cache or a
    // half-restored backup used to be indistinguishable from a picture that
    // existed, and the device would have been handed nothing.
    test('a row whose file has vanished is redrawn', () async {
      final beats = [beat('b1', 0)];
      final first = await service.ensureLuniiPortrait(
        series: series,
        beats: beats,
        world: world,
      );
      pictures.files.remove(first!.$1.fileKey);

      final second = await service.ensureLuniiPortrait(
        series: series,
        beats: beats,
        world: world,
      );
      expect(second, isNotNull);
      expect(pictures.files, contains(second!.$1.fileKey));
      // And the stale row goes with it. It did not, the first time: a dry run
      // and then a real one left the real library with two rows per story,
      // which is the same accumulate-rather-than-replace bug the chapter
      // pictures already had fixed.
      expect(
        (await repo.loadImages(
          's1',
        )).where((i) => i.kind == StoryImageKind.lunii),
        hasLength(1),
      );
    });

    test("carries the chosen character's sheet as the reference", () async {
      const pip = StoryCharacter(id: 'ch1', worldId: 'w1', name: 'Pip');
      await repo.saveCharacter(pip);
      final drawn = await service.ensureLuniiPortrait(
        series: series,
        beats: [beat('b1', 0, characters: 'Pip')],
        world: world,
        cast: const [pip],
      );
      expect(drawn, isNotNull);
      expect(
        illustrator.referenceCounts.last,
        1,
        reason: 'the device must show the same Pip as the story',
      );
      expect(illustrator.prompts.last, contains('A portrait of Pip'));
    });

    test('a world with no cast still gets a picture', () async {
      final drawn = await service.ensureLuniiPortrait(
        series: series,
        beats: [beat('b1', 0)],
        world: world,
      );
      expect(drawn, isNotNull);
      expect(illustrator.prompts.last, contains('A portrait'));
      expect(illustrator.referenceCounts.last, 0);
    });

    test('an empty story has nothing to draw', () async {
      expect(
        await service.ensureLuniiPortrait(
          series: series,
          beats: const [],
          world: world,
        ),
        isNull,
      );
    });
  });

  test('one picture failing does not abandon the rest', () async {
    illustrator.failuresLeft = 1; // the cover
    final reported = <String>[];
    final made = await service.illustrate(
      series: series,
      beats: [beat('b1', 0), beat('b2', 1), beat('b3', 2)],
      world: world,
      onStep: reported.add,
    );
    expect(made, isNotEmpty);
    expect(
      reported.where((s) => s.contains('could not draw')),
      hasLength(1),
      reason: 'the failure is reported, not swallowed',
    );
  });
}

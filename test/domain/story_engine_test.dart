import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/ai/ai_provider.dart';
import 'package:moonloom/adapters/ai/fake_ai_provider.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/cast_changes.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/models/story_segment.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';
import 'package:moonloom/domain/prompt_builder.dart';
import 'package:moonloom/domain/story_engine.dart';

import '../support/in_memory_storage_repo.dart';

/// Always returns an over-band, unsafe rating to exercise the guard + fallback.
class _UnsafeProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'Something far too intense for a toddler.',
    summary: 'too intense',
    rating: AgeRating.older, // exceeds a tiny child's band
  );
}

/// Always throws, to exercise the error path → fallback.
class _ThrowingProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async =>
      throw StateError('boom');
}

/// Always returns a safe, non-final segment — never wants to end the story.
class _NeverEndsProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'The journey continued on and on.',
    summary: 'still going',
    rating: AgeRating.tiny,
    openThreads: ['what next?'],
  );
}

/// Returns a safe segment marked as the final chapter.
/// Remembers the prompt it was handed, so a test can assert on what the
/// engine actually asked for.
class _RecordingProvider implements AiProvider {
  StoryPrompt? prompt;

  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt p) async {
    prompt ??= p; // the draft, not the editorial pass that follows it
    return const StorySegment(
      storyText: 'A lantern glowed in the willow tree, soft and low.',
      summary: 'A lantern in a willow.',
      rating: AgeRating.tiny,
    );
  }
}

/// Returns whatever chapter title it was built with.
class _TitledProvider implements AiProvider {
  _TitledProvider(this.title);
  final String title;

  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => StorySegment(
    storyText: 'A lantern glowed in the willow tree, soft and low.',
    summary: 'A lantern in a willow.',
    rating: AgeRating.tiny,
    chapterTitle: title,
  );
}

class _FinalProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'And so, warm and sleepy, everyone drifted off. The end.',
    summary: 'A peaceful ending.',
    rating: AgeRating.tiny,
    isFinal: true,
  );
}

/// Suggests a title, to exercise auto-naming.
class _TitlingProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => const StorySegment(
    storyText: 'A small lantern glowed in the willow tree.',
    summary: 'A lantern in a willow.',
    rating: AgeRating.tiny,
    // Wrapped in quotes and trailing punctuation, as models often do.
    suggestedTitle: '"The Lantern in the Willow."',
  );
}

/// Records the prompt it was handed so tests can assert on it.
class _CapturingProvider implements AiProvider {
  StoryPrompt? lastPrompt;

  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    lastPrompt = prompt;
    return const StorySegment(
      storyText: 'They waved from the hilltop until the boat was a dot.',
      summary: 'A warm goodbye.',
      rating: AgeRating.tiny,
    );
  }
}

/// Answers the draft call and the editorial call differently, so the second
/// pass can be told apart from the first. Optionally throws on the edit.
class _TwoPassProvider implements AiProvider {
  _TwoPassProvider({
    required this.draft,
    this.polish,
    this.throwOnPolish = false,
  });

  final StorySegment draft;
  final StorySegment? polish;
  final bool throwOnPolish;
  int calls = 0;
  final prompts = <StoryPrompt>[];

  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    prompts.add(prompt);
    if (calls++ == 0) return draft;
    if (throwOnPolish) throw StateError('polish failed');
    return polish ?? draft;
  }
}

void main() {
  const child = ChildProfile(id: 'c1', displayName: 'Aiden', age: 3);
  const series = Series(
    id: 's1',
    childId: 'c1',
    title: 'Cloud Pirates',
    theme: StoryTheme.cozy,
    heroMode: HeroMode.childAsHero,
    seedSummary: 'A cozy sky adventure.',
  );

  late InMemoryStorageRepo repo;

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveSeries(series);
  });

  test('takeTurn generates, vets, and persists a beat', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
      chosenTwist: 'gentle_surprise',
    );

    expect(beat.seq, 0);
    expect(beat.text, isNotEmpty);
    expect(beat.rating, AgeRating.tiny);

    final saved = await repo.loadBeats(series.id);
    expect(saved, hasLength(1));
  });

  test('consecutive turns increment seq and grow the story bible', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );

    final saved = await repo.loadBeats(series.id);
    expect(saved.map((b) => b.seq), [0, 1]);
    final updated = await repo.loadSeriesById(series.id);
    expect(updated!.storyBible, isNotEmpty);
  });

  test('unsafe output is rejected and falls back to a safe beat', () async {
    final engine = StoryEngine(
      ai: _UnsafeProvider(),
      repo: repo,
      maxRetries: 1,
    );
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    // Fallback is always within band.
    expect(beat.rating, AgeRating.tiny);
    expect(beat.text, isNot(contains('intense')));
    expect(await repo.loadBeats(series.id), hasLength(1));
  });

  test('provider errors fall back instead of breaking bedtime', () async {
    final engine = StoryEngine(ai: _ThrowingProvider(), repo: repo);
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(beat.text, isNotEmpty);
    expect(beat.rating, AgeRating.tiny);
    // The reason is exposed so the UI can warn instead of silently going generic.
    expect(engine.lastFallbackReason, contains('boom'));
  });

  test('lastFallbackReason is cleared after a successful turn', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    expect(engine.lastFallbackReason, isNull);
  });

  test('concurrent turns are serialized — no duplicate seq', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    // Fire two turns at once (e.g. background auto-complete + a user tap).
    final results = await Future.wait([
      engine.takeTurn(child: child, series: series, intent: StoryIntent.dice),
      engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.continued,
      ),
    ]);
    expect((results.map((b) => b.seq).toList()..sort()), [0, 1]);
    final saved = await repo.loadBeats(series.id);
    expect(saved.map((b) => b.seq).toList(), [0, 1]); // no duplicate
  });

  test('persists the final-chapter flag from the segment', () async {
    // Past the floor, the model's own is_final is honoured.
    final engine = StoryEngine(
      ai: _FinalProvider(),
      repo: repo,
      minChapters: 1,
    );
    final beat = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(beat.isFinal, isTrue);
    final saved = await repo.loadBeats(series.id);
    expect(saved.last.isFinal, isTrue);
  });

  test('a week, a few nights, or one sitting', () async {
    // "Long" has to mean long: asking for long stories and getting two
    // chapters is being told one thing and given another. Long is now exactly
    // seven — one a night, Monday to Sunday — so it is stated as a count
    // rather than a floor, and the reason travels with it.
    // A fresh series per length. Sharing one made each call the *next*
    // chapter of the last, so the mini was asked for as chapter three — which
    // is a real situation, but not the one under test here.
    Future<String> promptFor(DetailLevel level) async {
      final ai = _RecordingProvider();
      final own = Series(
        id: 's-${level.name}',
        childId: series.childId,
        title: 'For ${level.name}',
        theme: series.theme,
        heroMode: series.heroMode,
        seedSummary: series.seedSummary,
      );
      await repo.saveSeries(own);
      await StoryEngine(ai: ai, repo: repo).takeTurn(
        child: child.copyWith(detailLevel: level),
        series: own,
        intent: StoryIntent.dice,
      );
      return ai.prompt!.system;
    }

    final long = await promptFor(DetailLevel.long);
    expect(long, contains('exactly 7 short chapters'));
    expect(long, contains('one for each night of the week'));
    expect(long, isNot(contains('7–7')));

    expect(await promptFor(DetailLevel.medium), contains('of at least 3'));

    // A mini is one sitting, so it never sees the "how many chapters" brief
    // at all — chapter one is already the last.
    expect(await promptFor(DetailLevel.short), contains('MINI EPISODE'));
  });

  group('a long story is exactly a week', () {
    // Both bounds are enforced in code, not asked for in the prompt. Asking
    // alone is what produced two-chapter "long" stories: a model handed a
    // range will take the shortest end of it, and a model told to keep going
    // will keep going. So the floor overrules an early ending and the ceiling
    // forces a late one, and neither depends on the model cooperating.
    test(
      'it cannot finish early, however final the model says it is',
      () async {
        final engine = StoryEngine(ai: _FinalProvider(), repo: repo);
        final longReader = child.copyWith(detailLevel: DetailLevel.long);
        var beat = await engine.takeTurn(
          child: longReader,
          series: series,
          intent: StoryIntent.dice,
        );
        final endings = <int>[];
        for (var i = 1; i < 7; i++) {
          if (beat.isFinal) endings.add(beat.seq);
          beat = await engine.takeTurn(
            child: longReader,
            series: series,
            intent: StoryIntent.continued,
          );
        }
        // Every chapter claimed to be the last; only the seventh was allowed to
        // be, and the six before it were overruled.
        expect(endings, isEmpty);
        expect(beat.seq, 6); // 0-based: the seventh chapter
        expect(beat.isFinal, isTrue);
      },
    );

    test('it cannot run past seven, however much the model wants to', () async {
      final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
      final longReader = child.copyWith(detailLevel: DetailLevel.long);
      Beat beat = await engine.takeTurn(
        child: longReader,
        series: series,
        intent: StoryIntent.dice,
      );
      for (var i = 0; i < 12 && !beat.isFinal; i++) {
        beat = await engine.takeTurn(
          child: longReader,
          series: series,
          intent: StoryIntent.continued,
        );
      }
      expect(beat.isFinal, isTrue);
      expect(beat.seq, 6);
      // A forced ending still ties off, or a child is left on a hook with no
      // chapter to resolve it.
      expect(beat.openThreads, isEmpty);
    });

    // The two tests above drive the engine with their own loop, and the engine
    // was right all along: seven. The chapter screen drove it with a different
    // loop holding a constant six, so every week-long story stopped on its
    // sixth night. This is that loop, asking the engine how many to write.
    test(
      'driven the way the chapter screen drives it, a week is seven',
      () async {
        final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
        final longReader = child.copyWith(detailLevel: DetailLevel.long);
        final beats = <Beat>[];
        while (beats.length < engine.chaptersFor(series, longReader) &&
            !(beats.isNotEmpty && beats.last.isFinal)) {
          beats.add(
            await engine.takeTurn(
              child: longReader,
              series: series,
              intent: beats.isEmpty ? StoryIntent.dice : StoryIntent.continued,
            ),
          );
        }
        expect(beats, hasLength(7));
        expect(beats.last.isFinal, isTrue);
        expect(beats.take(6).where((b) => b.isFinal), isEmpty);
      },
    );

    test('each length asks for its own number of chapters', () {
      final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
      int count(DetailLevel level) =>
          engine.chaptersFor(series, child.copyWith(detailLevel: level));
      expect(count(DetailLevel.short), 1);
      expect(count(DetailLevel.medium), 4);
      expect(count(DetailLevel.long), 7);
    });

    // A story is as long as it was made to be. The child's default only
    // decides the length of the *next* story; changing it mid-week must not
    // turn a week already under way into a mini.
    test("the story's own length wins over the child's default", () {
      final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
      // Built rather than copied: a story's length is fixed when it is made,
      // so copyWith deliberately has no way to change it.
      const week = Series(
        id: 's1',
        childId: 'c1',
        title: 'Cloud Pirates',
        theme: StoryTheme.cozy,
        detailLevel: DetailLevel.long,
      );
      final nowPrefersMinis = child.copyWith(detailLevel: DetailLevel.short);
      expect(engine.chaptersFor(week, nowPrefersMinis), 7);
    });

    test('a story from before stories had a length uses the child', () {
      final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
      expect(series.detailLevel, isNull, reason: 'the fixture is old-style');
      expect(
        engine.chaptersFor(
          series,
          child.copyWith(detailLevel: DetailLevel.long),
        ),
        7,
      );
    });

    test('a medium story still ends before a long one', () async {
      final engine = StoryEngine(ai: _NeverEndsProvider(), repo: repo);
      Beat beat = await engine.takeTurn(
        child: child.copyWith(detailLevel: DetailLevel.medium),
        series: series,
        intent: StoryIntent.dice,
      );
      for (var i = 0; i < 12 && !beat.isFinal; i++) {
        beat = await engine.takeTurn(
          child: child.copyWith(detailLevel: DetailLevel.medium),
          series: series,
          intent: StoryIntent.continued,
        );
      }
      expect(beat.seq, 3); // four chapters
    });

    test('an explicit cap still overrules the length', () async {
      // The cap exists to stop runaway generation burning through quota, so
      // it has to win even over a length whose floor is higher than it.
      final engine = StoryEngine(
        ai: _NeverEndsProvider(),
        repo: repo,
        maxChapters: 2,
      );
      Beat beat = await engine.takeTurn(
        child: child.copyWith(detailLevel: DetailLevel.long),
        series: series,
        intent: StoryIntent.dice,
      );
      for (var i = 0; i < 6 && !beat.isFinal; i++) {
        beat = await engine.takeTurn(
          child: child.copyWith(detailLevel: DetailLevel.long),
          series: series,
          intent: StoryIntent.continued,
        );
      }
      expect(beat.seq, 1);
      expect(beat.isFinal, isTrue);
    });
  });

  test('naming the story also names the world it was created with', () async {
    // A world made alongside an unnamed story takes the story's placeholder,
    // because there is nothing else to call it yet. It should not still be
    // called "Naming it…" once the story has a real name.
    const placeholder = 'Naming it…';
    const world = World(id: 'w1', childId: 'kid', name: placeholder);
    await repo.saveWorld(world);
    final unnamed = Series(
      id: 's-auto',
      childId: child.id,
      title: placeholder,
      theme: StoryTheme.cozy,
      autoTitle: true,
      worldId: world.id,
    );
    await repo.saveSeries(unnamed);

    await StoryEngine(
      ai: _TitlingProvider(),
      repo: repo,
    ).takeTurn(child: child, series: unnamed, intent: StoryIntent.dice);

    final named = await repo.loadSeriesById('s-auto');
    expect(named!.title, isNot(placeholder));
    expect(named.autoTitle, isFalse);
    expect((await repo.loadWorldById('w1'))!.name, named.title);
  });

  test('a world the grown-up named keeps its name', () async {
    const world = World(id: 'w2', childId: 'kid', name: 'Splat the Cat');
    await repo.saveWorld(world);
    final unnamed = Series(
      id: 's-auto2',
      childId: child.id,
      title: 'Naming it…',
      theme: StoryTheme.cozy,
      autoTitle: true,
      worldId: world.id,
    );
    await repo.saveSeries(unnamed);

    await StoryEngine(
      ai: _TitlingProvider(),
      repo: repo,
    ).takeTurn(child: child, series: unnamed, intent: StoryIntent.dice);

    expect((await repo.loadWorldById('w2'))!.name, 'Splat the Cat');
  });

  test('a chapter title that is only a number is dropped', () async {
    // The list already prints the number, so "Chapter One" came out as
    // "Chapter 1 · Chapter One". An absent title renders as the plain
    // number, which is what the model meant anyway.
    for (final placeholder in [
      'Chapter One',
      'Chapter 4',
      'chapter three',
      'Chapitre 2',
      'Capítulo 5',
      'Chapter',
    ]) {
      final beat = await StoryEngine(
        ai: _TitledProvider(placeholder),
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.title, isEmpty, reason: '"$placeholder" is not a title');
    }
  });

  test('a chapter cannot reuse the title of the one before it', () async {
    // Two chapters running came back as "The Whispering Nebula", which tells a
    // child nothing about either. The prompt now lists the titles already
    // used; this is the backstop for when it is ignored anyway.
    final engine = StoryEngine(
      ai: _TitledProvider('The Whispering Nebula'),
      repo: repo,
    );
    final first = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    expect(first.title, 'The Whispering Nebula');
    final second = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(second.title, isEmpty, reason: 'not the same name twice');
  });

  test('a real chapter title survives, numbers in it and all', () async {
    for (final real in [
      'The Lost Mitten',
      'Three Little Bells',
      'Part of It',
    ]) {
      final beat = await StoryEngine(
        ai: _TitledProvider(real),
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.title, real);
    }
  });

  test('a story is not allowed to end in chapter one', () async {
    // A model told "about 3 to 6 chapters" ended one in two. Asking again is
    // not enough on its own, so an early is_final is overruled and the story
    // carries on.
    final engine = StoryEngine(ai: _FinalProvider(), repo: repo);
    final first = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.dice,
    );
    expect(first.isFinal, isFalse, reason: 'too early to end');
    // And the next turn is still allowed to happen.
    final second = await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.continued,
    );
    expect(second.seq, 1);
  });

  test(
    'the chapter cap forces a final chapter even if the model won\'t',
    () async {
      final engine = StoryEngine(
        ai: _NeverEndsProvider(),
        repo: repo,
        maxChapters: 3,
      );
      Beat last = await engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.dice,
      );
      for (var i = 0; i < 5 && !last.isFinal; i++) {
        last = await engine.takeTurn(
          child: child,
          series: series,
          intent: StoryIntent.continued,
        );
      }
      expect(last.isFinal, isTrue);
      expect(last.seq, 2); // 0-based: the 3rd chapter is forced final
      expect(last.openThreads, isEmpty); // no dangling hook on the last chapter
    },
  );

  test('dice/option twists feed the learned profile', () async {
    final engine = StoryEngine(ai: const FakeAiProvider(), repo: repo);
    await engine.takeTurn(
      child: child,
      series: series,
      intent: StoryIntent.option,
      chosenTwist: 'mystery_door',
    );
    final learned = await repo.loadLearnedProfile(child.id);
    expect(learned?.twistAffinity['mystery_door'], 1);
  });

  group('auto-naming', () {
    const unnamed = Series(
      id: 's2',
      childId: 'c1',
      title: 'Naming it…',
      theme: StoryTheme.cozy,
      autoTitle: true,
      seedSummary: 'A cozy sky adventure.',
    );

    test('the first chapter names the story from its content', () async {
      await repo.saveSeries(unnamed);
      final engine = StoryEngine(ai: _TitlingProvider(), repo: repo);
      await engine.takeTurn(
        child: child,
        series: unnamed,
        intent: StoryIntent.dice,
      );
      final saved = await repo.loadSeriesById(unnamed.id);
      expect(saved!.title, 'The Lantern in the Willow');
      expect(saved.autoTitle, isFalse); // named once, then left alone
    });

    test('a title the grown-up chose is never overwritten', () async {
      final engine = StoryEngine(ai: _TitlingProvider(), repo: repo);
      await engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.dice,
      );
      final saved = await repo.loadSeriesById(series.id);
      expect(saved!.title, 'Cloud Pirates');
    });

    test('a fallback chapter leaves the story unnamed for next time', () async {
      await repo.saveSeries(unnamed);
      final engine = StoryEngine(ai: _ThrowingProvider(), repo: repo);
      await engine.takeTurn(
        child: child,
        series: unnamed,
        intent: StoryIntent.dice,
      );
      final saved = await repo.loadSeriesById(unnamed.id);
      expect(saved!.autoTitle, isTrue);
    });
  });

  group('paragraph repair', () {
    const draft = 'One one one.\n\nTwo two two.\n\nThree three three.';

    test('single newlines are promoted back to real breaks', () {
      final fixed = StoryEngine.restoreParagraphs(
        'One one.\nTwo two.\nThree three.',
        draft,
      );
      expect(fixed, 'One one.\n\nTwo two.\n\nThree three.');
    });

    test('a chapter flattened to one block is rejected', () {
      expect(
        StoryEngine.restoreParagraphs('All of it as one long block.', draft),
        isNull,
      );
    });

    test('text that already has its breaks is left alone', () {
      const good = 'A.\n\nB.\n\nC.\n\nD.';
      expect(StoryEngine.restoreParagraphs(good, draft), good);
    });

    test('merging two short paragraphs is allowed', () {
      final fixed = StoryEngine.restoreParagraphs('A and B.\n\nC.', draft);
      expect(fixed, 'A and B.\n\nC.');
    });

    test('a single-paragraph draft imposes nothing', () {
      expect(StoryEngine.restoreParagraphs('anything', 'one para'), 'anything');
    });
  });

  group('editorial second pass', () {
    // 12 words, so the guard bands land at 7 and 18.
    const draft = StorySegment(
      storyText: 'The cat sat. It was very very nice and it sat there.',
      summary: 'A cat sat.',
      rating: AgeRating.tiny,
      chapterTitle: '"The Sitting Cat."',
    );

    test('the polished chapter is what gets saved', () async {
      final ai = _TwoPassProvider(
        draft: draft,
        polish: const StorySegment(
          storyText:
              'The cat sat on the warm step and watched the sleepy garden.',
          summary: 'A cat watches the garden.',
          rating: AgeRating.tiny,
          chapterTitle: 'The Sitting Cat',
        ),
      );
      final beat = await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(ai.calls, 2, reason: 'draft, then edit');
      expect(beat.text, contains('sleepy garden'));
      expect(beat.summary, 'A cat watches the garden.');
    });

    test('the editor is shown the draft it has to work on', () async {
      final ai = _TwoPassProvider(draft: draft);
      await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      final edit = ai.prompts.last;
      expect(edit.user, contains('The cat sat.'));
      // Written for the ear, and for the band the child is actually in.
      expect(edit.system, contains('audiobook'));
      expect(edit.system, contains('ages 2–4'));
      expect(edit.system, contains('no semicolons'));
      // The length band comes from the draft's own word count.
      expect(edit.system, contains('the draft is 12 words'));
    });

    test('a polish that comes back as a summary is thrown away', () async {
      final ai = _TwoPassProvider(
        draft: draft,
        polish: const StorySegment(
          storyText: 'A cat.',
          summary: 'A cat.',
          rating: AgeRating.tiny,
        ),
      );
      final beat = await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.text, contains('very very nice'), reason: 'draft kept');
    });

    test('a polish that errors still leaves a chapter', () async {
      final ai = _TwoPassProvider(draft: draft, throwOnPolish: true);
      final beat = await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.text, contains('very very nice'));
    });

    test('the edit cannot decide the story is over', () async {
      final ai = _TwoPassProvider(
        draft: draft,
        polish: const StorySegment(
          storyText:
              'The cat sat on the warm step and watched the sleepy garden.',
          summary: 'A cat watches the garden.',
          rating: AgeRating.tiny,
          isFinal: true, // the draft said otherwise
        ),
      );
      final beat = await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.isFinal, isFalse);
    });

    test('the chapter title is tidied before it is saved', () async {
      final ai = _TwoPassProvider(draft: draft);
      final beat = await StoryEngine(
        ai: ai,
        repo: repo,
        refinePass: false,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(beat.title, 'The Sitting Cat');
    });

    test('a fallback chapter is never sent for polishing', () async {
      final ai = _TwoPassProvider(draft: draft);
      await StoryEngine(
        ai: _ThrowingProvider(),
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(ai.calls, 0);
    });
  });

  group('cast changes', () {
    const world = World(
      id: 'w1',
      childId: 'c1',
      name: 'Splat the Cat',
      pendingCastChanges: CastChanges(left: ['Splat — a big black cat']),
    );
    const episode = Series(
      id: 's3',
      childId: 'c1',
      worldId: 'w1',
      title: 'A New Day',
      theme: StoryTheme.cozy,
    );

    setUp(() async {
      await repo.saveWorld(world);
      await repo.saveSeries(episode);
    });

    test('the first chapter is told to write the character out', () async {
      final ai = _CapturingProvider();
      // No editorial pass: these assert on the *generation* prompt, and the
      // refinement call would otherwise be the last one captured.
      await StoryEngine(
        ai: ai,
        repo: repo,
        refinePass: false,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);
      expect(ai.lastPrompt!.user, contains('Leaving the story'));
      expect(ai.lastPrompt!.user, contains('Splat'));
      // Said goodbye — the world's cast is settled again.
      final saved = await repo.loadWorldById(world.id);
      expect(saved!.pendingCastChanges.isEmpty, isTrue);
    });

    test('a later chapter does not repeat the goodbye', () async {
      final ai = _CapturingProvider();
      final engine = StoryEngine(ai: ai, repo: repo, refinePass: false);
      await engine.takeTurn(
        child: child,
        series: episode,
        intent: StoryIntent.dice,
      );
      await engine.takeTurn(
        child: child,
        series: episode,
        intent: StoryIntent.continued,
      );
      expect(ai.lastPrompt!.user, isNot(contains('Leaving the story')));
    });

    test('a fallback chapter keeps the goodbye pending', () async {
      await StoryEngine(
        ai: _ThrowingProvider(),
        repo: repo,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);
      final saved = await repo.loadWorldById(world.id);
      expect(saved!.pendingCastChanges.left, ['Splat — a big black cat']);
    });
  });

  group('a world remembers who lives in it', () {
    // Pip came out a dragon, a star, a fish, a child, an otter, a kitten and
    // a fox across one child's library. Every chapter had recorded who was in
    // it; nothing ever promoted them, so each new episode started with an
    // empty cast list and invented Pip again.
    const world = World(id: 'w1', childId: 'c1', name: "Pip's Adventures");

    Series episodeOf(String id) => Series(
      id: id,
      childId: 'c1',
      title: 'Episode $id',
      theme: StoryTheme.cozy,
      worldId: 'w1',
      seedSummary: 'A gentle sea adventure.',
    );

    test('a chapter puts its characters into the world', () async {
      await repo.saveWorld(world);
      final episode = episodeOf('e1');
      await repo.saveSeries(episode);

      await StoryEngine(
        ai: _CastProvider(const ['Pip, an axolotl', 'Coral — a sea turtle']),
        repo: repo,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);

      final cast = await repo.loadCharacters('w1');
      expect(cast.map((c) => c.name), containsAll(['Pip', 'Coral']));
      // The article is dropped on the way in, so a cast list reads the same
      // whichever chapter each line came from — "Pip - axolotl" beside
      // "Coral - sea turtle", never "an axolotl" beside "sea turtle". The
      // species is what has to survive, and does.
      expect(
        cast.firstWhere((c) => c.name == 'Pip').description,
        'axolotl',
        reason: 'the species is the whole point',
      );
      expect(
        cast.firstWhere((c) => c.name == 'Coral').description,
        'sea turtle',
        reason: 'an em dash separates just as well as a comma',
      );
    });

    test('the next story is told who they are', () async {
      await repo.saveWorld(world);
      final first = episodeOf('e1');
      await repo.saveSeries(first);
      await StoryEngine(
        ai: _CastProvider(const ['Pip, an axolotl']),
        repo: repo,
      ).takeTurn(child: child, series: first, intent: StoryIntent.dice);

      final second = episodeOf('e2');
      await repo.saveSeries(second);
      final ai = _RecordingProvider();
      await StoryEngine(
        ai: ai,
        repo: repo,
      ).takeTurn(child: child, series: second, intent: StoryIntent.dice);

      // Stored as a promptLine, which normalises the separator to an em dash
      // and the description to its article-less form.
      expect(ai.prompt!.user, contains('Pip'));
      expect(ai.prompt!.user, contains('axolotl'));
      expect(ai.prompt!.user, contains('ALREADY EXIST'));
      expect(ai.prompt!.user, contains('must not change'));
    });

    test('an existing character is never overwritten', () async {
      // A grown-up may have corrected the description in "Edit world", and a
      // later chapter that drifted must not undo the correction.
      await repo.saveWorld(world);
      await repo.saveCharacter(
        const StoryCharacter(
          id: 'ch1',
          worldId: 'w1',
          name: 'Pip',
          description: 'a small red fox',
        ),
      );
      final episode = episodeOf('e1');
      await repo.saveSeries(episode);

      await StoryEngine(
        ai: _CastProvider(const ['Pip, a penguin']),
        repo: repo,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);

      final pip = (await repo.loadCharacters(
        'w1',
      )).where((c) => c.name == 'Pip');
      expect(pip, hasLength(1), reason: 'not a second Pip either');
      expect(pip.single.description, 'a small red fox');
    });

    test('a story with no world saves nobody', () async {
      await StoryEngine(
        ai: _CastProvider(const ['Pip, an axolotl']),
        repo: repo,
      ).takeTurn(child: child, series: series, intent: StoryIntent.dice);
      expect(await repo.loadCharacters('w1'), isEmpty);
    });

    test('a fallback chapter does not teach the world anything', () async {
      // A generic chapter written because the provider failed is not evidence
      // about who lives here, and letting it name the cast would lock in
      // whoever the placeholder happened to mention.
      await repo.saveWorld(world);
      final episode = episodeOf('e1');
      await repo.saveSeries(episode);
      await StoryEngine(
        ai: _FailingProvider(),
        repo: repo,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);
      expect(await repo.loadCharacters('w1'), isEmpty);
    });

    test('the cast stops growing before it stops steering', () async {
      await repo.saveWorld(world);
      final episode = episodeOf('e1');
      await repo.saveSeries(episode);
      await StoryEngine(
        ai: _CastProvider([
          for (var i = 0; i < 30; i++) 'Friend$i, a creature',
        ]),
        repo: repo,
      ).takeTurn(child: child, series: episode, intent: StoryIntent.dice);
      expect((await repo.loadCharacters('w1')).length, lessThanOrEqualTo(12));
    });
  });
}

/// Returns a chapter whose cast list is whatever the test asked for.
class _CastProvider implements AiProvider {
  _CastProvider(this.cast);
  final List<String> cast;

  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async => StorySegment(
    storyText: 'They swam together through the warm shallows.',
    summary: 'A swim in the shallows.',
    rating: AgeRating.tiny,
    characters: cast,
  );
}

/// Always fails, so the engine falls back to a generic chapter.
class _FailingProvider implements AiProvider {
  @override
  ProviderId get id => ProviderId.fake;
  @override
  Future<bool> isReady() async => true;
  @override
  Future<StorySegment> generate(StoryPrompt prompt) async =>
      throw StateError('no');
}

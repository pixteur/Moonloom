import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/series_service.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  late InMemoryStorageRepo repo;
  late SeriesService series;

  const story = Series(
    id: 's1',
    childId: 'c1',
    title: 'Obsidian Stone',
    theme: StoryTheme.adventure,
  );

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveSeries(story);
    series = SeriesService(repo);
  });

  test('a fresh story has no position to resume from', () {
    expect(story.lastReadSeq, isNull);
    expect(story.isInProgress, isFalse);
  });

  test('opening a chapter records where the child got to', () async {
    final read = await series.markRead(story, 3);
    expect(read.lastReadSeq, 3);
    expect(read.isInProgress, isTrue);
    expect((await repo.loadSeriesById('s1'))!.lastReadSeq, 3);
  });

  test('chapter 1 alone is not "in progress"', () async {
    // Opening the first chapter shouldn't make the shelf offer to "continue"
    // a story that hasn't really been started.
    final read = await series.markRead(story, 0);
    expect(read.lastReadSeq, 0);
    expect(read.isInProgress, isFalse);
  });

  test('re-reading an earlier chapter does not rewind the mark', () async {
    final far = await series.markRead(story, 5);
    final back = await series.markRead(far, 1);
    expect(back.lastReadSeq, 5, reason: 'resume from the furthest point');
    expect(back.lastReadAt, isNotNull);
  });
}

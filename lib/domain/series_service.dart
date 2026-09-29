import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/beat.dart';
import 'models/child_profile.dart';
import 'models/series.dart';
import 'story_engine.dart';

/// Manages a child's storylines: list (the library), create (with theme + hero),
/// archive, and branch (a new series, optionally forked from a beat).
/// See `docs/architecture.md`, `docs/data-model.md`.
class SeriesService {
  SeriesService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  /// Active series for a child (the library), newest first.
  Future<List<Series>> forChild(String childId) async {
    final all = await _repo.loadSeries(childId);
    return all.where((s) => s.status == SeriesStatus.active).toList();
  }

  Future<List<Series>> archived(String childId) async {
    final all = await _repo.loadSeries(childId);
    return all.where((s) => s.status == SeriesStatus.archived).toList();
  }

  Future<Series> create({
    required String childId,
    required String title,
    required StoryTheme theme,
    List<StoryTheme> extraThemes = const [],
    bool autoTitle = false,
    String? worldId,
    String? customTheme,
    HeroMode heroMode = HeroMode.surprise,
    String? heroName,
    String seedSummary = '',
    String? baseLanguage,
    bool bilingualEnabled = false,
    String? secondaryLanguage,
    BilingualBlend? bilingualBlend,
    DetailLevel? detailLevel,
    String? branchedFromBeatId,
  }) async {
    final series = Series(
      id: _uuid.v4(),
      childId: childId,
      title: title,
      theme: theme,
      extraThemes: extraThemes,
      autoTitle: autoTitle,
      worldId: worldId,
      customTheme: customTheme,
      heroMode: heroMode,
      heroName: heroName,
      seedSummary: seedSummary,
      baseLanguage: baseLanguage,
      bilingualEnabled: bilingualEnabled,
      secondaryLanguage: secondaryLanguage,
      bilingualBlend: bilingualBlend,
      detailLevel: detailLevel,
      branchedFromBeatId: branchedFromBeatId,
    );
    await _repo.saveSeries(series);
    return series;
  }

  Future<void> archive(Series series) =>
      _repo.saveSeries(series.copyWith(status: SeriesStatus.archived));

  /// Remember where the child got to. Called when a chapter is opened, so the
  /// bookshelf can offer to pick the story back up. Reading an earlier chapter
  /// again doesn't rewind the mark — the furthest point reached is the useful
  /// one to resume from.
  Future<Series> markRead(Series series, int seq) async {
    final furthest = seq > (series.lastReadSeq ?? -1)
        ? seq
        : series.lastReadSeq!;
    final updated = series.copyWith(
      lastReadSeq: furthest,
      lastReadAt: DateTime.now(),
    );
    await _repo.saveSeries(updated);
    return updated;
  }

  /// Change the languages a story is told in.
  ///
  /// Written out in full rather than through `copyWith`, because turning
  /// bilingual mode off has to *clear* the second language and the blend —
  /// and a copyWith that treats null as "leave it alone" cannot express that.
  ///
  /// Only future chapters are affected: the ones already written keep the
  /// words they were written in. Narration is keyed by language too, so a
  /// story whose base language changes will re-record on next play — the old
  /// recordings stay on disk under the old language.
  Future<Series> setLanguages(
    Series series, {
    required String? baseLanguage,
    required bool bilingualEnabled,
    required String? secondaryLanguage,
    required BilingualBlend? bilingualBlend,
  }) async {
    final updated = Series(
      id: series.id,
      childId: series.childId,
      title: series.title,
      theme: series.theme,
      extraThemes: series.extraThemes,
      autoTitle: series.autoTitle,
      worldId: series.worldId,
      customTheme: series.customTheme,
      heroMode: series.heroMode,
      heroName: series.heroName,
      baseLanguage: baseLanguage,
      bilingualEnabled: bilingualEnabled,
      secondaryLanguage: bilingualEnabled ? secondaryLanguage : null,
      bilingualBlend: bilingualEnabled ? bilingualBlend : null,
      detailLevel: series.detailLevel,
      seedSummary: series.seedSummary,
      storyBible: series.storyBible,
      branchedFromBeatId: series.branchedFromBeatId,
      status: series.status,
      lastReadSeq: series.lastReadSeq,
      lastReadAt: series.lastReadAt,
    );
    await _repo.saveSeries(updated);
    return updated;
  }

  /// Permanently delete a series and its chapters (FK cascade).
  Future<void> delete(String id) => _repo.deleteSeries(id);

  /// Branch a new series from an existing one, optionally forking from a beat.
  Future<Series> branch({
    required Series from,
    required String title,
    String? fromBeatId,
  }) {
    return create(
      childId: from.childId,
      title: title,
      theme: from.theme,
      extraThemes: from.extraThemes,
      customTheme: from.customTheme,
      heroMode: from.heroMode,
      heroName: from.heroName,
      seedSummary: from.seedSummary,
      baseLanguage: from.baseLanguage,
      bilingualEnabled: from.bilingualEnabled,
      secondaryLanguage: from.secondaryLanguage,
      bilingualBlend: from.bilingualBlend,
      detailLevel: from.detailLevel,
      branchedFromBeatId: fromBeatId,
    );
  }

  /// Run every chapter of [source] through the editorial second pass and save
  /// the result as a **new** story, leaving the original untouched.
  ///
  /// Chapters are refined in order and each one sees the summaries of the
  /// chapters before it, so continuity fixes have the same context they get
  /// during a normal turn. A chapter whose polish fails its checks is copied
  /// across unchanged rather than dropped — a refined story is never shorter
  /// than the one it came from.
  ///
  /// [onProgress] reports chapters completed, for a progress indicator.
  Future<Series> refineIntoNewVersion({
    required StoryEngine engine,
    required ChildProfile child,
    required Series source,
    String? title,
    void Function(int done, int total)? onProgress,
  }) async {
    final beats = await _repo.loadBeats(source.id);
    if (beats.isEmpty) {
      throw StateError('That story has no chapters to refine yet.');
    }
    final copy = await branch(
      from: source,
      title: title ?? '${source.title} Refined',
    );

    final earlier = <Beat>[];
    for (final beat in beats) {
      final polished = await engine.refineExisting(
        child: child,
        series: source,
        beat: beat,
        earlier: List.of(earlier),
        totalChapters: beats.length,
      );
      final saved = Beat(
        id: _uuid.v4(),
        seriesId: copy.id,
        childId: beat.childId,
        seq: beat.seq,
        intent: beat.intent,
        chosenTwist: beat.chosenTwist,
        text: polished?.storyText ?? beat.text,
        summary: polished?.summary ?? beat.summary,
        title: polished?.chapterTitle ?? beat.title,
        rating: beat.rating,
        setting: polished?.setting ?? beat.setting,
        characters: polished?.characters ?? beat.characters,
        openThreads: polished?.openThreads ?? beat.openThreads,
        language: beat.language,
        isFinal: beat.isFinal,
        // The editor wrote this against the finished prose; dropping it here
        // would leave the copy silent on how to read itself.
        narration: polished?.narration ?? beat.narration,
      );
      await _repo.saveBeat(saved);
      earlier.add(saved);
      onProgress?.call(earlier.length, beats.length);
    }

    await _repo.saveSeries(copy.copyWith(storyBible: source.storyBible));
    return copy;
  }
}

import 'child_profile.dart';

/// A storyline. A child can have several running in parallel; "branching"
/// starts a new one (optionally forked from a beat). See `docs/data-model.md`.
class Series {
  const Series({
    required this.id,
    required this.childId,
    required this.title,
    required this.theme,
    this.extraThemes = const [],
    this.autoTitle = false,
    this.worldId,
    this.customTheme,
    this.heroMode = HeroMode.surprise,
    this.heroName,
    this.baseLanguage,
    this.bilingualEnabled = false,
    this.secondaryLanguage,
    this.bilingualBlend,
    this.detailLevel,
    this.seedSummary = '',
    this.storyBible = '',
    this.branchedFromBeatId,
    this.status = SeriesStatus.active,
    this.lastReadSeq,
    this.lastReadAt,
  });

  final String id;
  final String childId;
  final String title;

  /// The World (universe) this episode belongs to, or null for a standalone
  /// story. Episodes in the same world share characters + premise.
  final String? worldId;

  /// The series' overall flavour, chosen at start.
  final StoryTheme theme;

  /// Up to two further flavours blended with [theme] (the chooser allows three
  /// picks in total). Empty for a single-theme story.
  final List<StoryTheme> extraThemes;

  /// True while [title] is a placeholder waiting to be replaced by a title the
  /// model derives from the first chapter. Cleared once named.
  final bool autoTitle;

  /// [theme] plus [extraThemes], in the order they were picked.
  List<StoryTheme> get allThemes => [theme, ...extraThemes];

  /// Free-text flavour when [theme] is [StoryTheme.custom].
  final String? customTheme;

  final HeroMode heroMode;
  final String? heroName;

  /// The language this story is told in. Null means the child's own — which is
  /// every story written before a household needed one child to have stories
  /// in two languages. Resolve it with [languageFor], never by reading the
  /// child directly, or half the app will disagree with the other half about
  /// what language a story is in.
  final String? baseLanguage;

  /// Bilingual mode is a modifier, independent of [theme] — any story can use
  /// it. [secondaryLanguage] is woven into [baseLanguage], not the reverse.
  final bool bilingualEnabled;
  final String? secondaryLanguage;
  final BilingualBlend? bilingualBlend;

  /// The shape this story was asked for — a mini, a few nights, or a week.
  ///
  /// Recorded so the bookshelf can group by it. Nullable because stories
  /// written before this existed never had one, and inferring it from the
  /// chapter count would mislabel every story still being written: a week-long
  /// story on chapter two is not a medium one.
  final DetailLevel? detailLevel;

  /// Premise this series starts from (distilled from the quiz + briefs).
  final String seedSummary;

  /// Rolling summary the engine maintains for cheap long-term continuity.
  final String storyBible;

  /// If this series was forked from a beat in another series.
  final String? branchedFromBeatId;

  final SeriesStatus status;

  /// Where the child got to: the chapter last opened, and when. Drives
  /// "Continue — Chapter 4" on the bookshelf. Null until a chapter is read.
  final int? lastReadSeq;
  final DateTime? lastReadAt;

  /// True once the story has been picked up and left part-way through.
  bool get isInProgress => lastReadSeq != null && lastReadSeq! > 0;

  Series copyWith({
    String? title,
    bool? autoTitle,
    String? worldId,
    String? seedSummary,
    String? storyBible,
    SeriesStatus? status,
    int? lastReadSeq,
    DateTime? lastReadAt,
  }) {
    return Series(
      id: id,
      childId: childId,
      title: title ?? this.title,
      theme: theme,
      extraThemes: extraThemes,
      autoTitle: autoTitle ?? this.autoTitle,
      worldId: worldId ?? this.worldId,
      customTheme: customTheme,
      heroMode: heroMode,
      heroName: heroName,
      baseLanguage: baseLanguage,
      bilingualEnabled: bilingualEnabled,
      secondaryLanguage: secondaryLanguage,
      bilingualBlend: bilingualBlend,
      detailLevel: detailLevel,
      seedSummary: seedSummary ?? this.seedSummary,
      storyBible: storyBible ?? this.storyBible,
      branchedFromBeatId: branchedFromBeatId,
      status: status ?? this.status,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}

/// The ~16 series themes surfaced in the chooser. See `docs/ui-ux.md`.
enum StoryTheme {
  adventure,
  technical,
  nature,
  documentary,
  learning,
  cozy,
  feelings,
  mystery,
  silly,
  fairytale,
  history,
  aroundTheWorld,
  superhero,
  mindfulness,
  sliceOfLife,
  surprise,
  custom,
}

/// Who the hero is — chosen when a series begins.
enum HeroMode { childAsHero, namedHero, surprise }

/// How much of the second language to weave in (bilingual mode).
enum BilingualBlend { sprinkle, phrases, alternating }

enum SeriesStatus { active, archived }

/// The language a story is actually told in.
///
/// One place, because the answer is needed by the prompt, the voice, the audio
/// cache key and every export — and if any of them disagreed, a story would be
/// written in one language and spoken in another, or narration cached under a
/// key nothing later looks up.
String languageFor(Series? series, String? childLanguage) =>
    series?.baseLanguage?.trim().isNotEmpty == true
    ? series!.baseLanguage!.trim()
    : (childLanguage?.trim().isNotEmpty == true ? childLanguage!.trim() : 'en');

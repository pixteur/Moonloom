import 'cast_changes.dart';
import 'series.dart';

/// A story "universe" — a reusable world (e.g. "Splat the Cat") that holds a
/// premise + a cast of [Character]s and spawns many different episodes (each an
/// episode = a [Series]). See `docs/data-model.md`.
class World {
  const World({
    required this.id,
    required this.childId,
    required this.name,
    this.premise = '',
    this.theme = StoryTheme.cozy,
    this.extraThemes = const [],
    this.voiceName = '',
    this.styleGuide = '',
    this.pendingCastChanges = CastChanges.none,
  });

  final String id;
  final String childId;

  /// The world's name, shown on the bookshelf (e.g. "Splat the Cat").
  final String name;

  /// A short description of the world used to keep every episode consistent.
  final String premise;

  /// Default flavour for episodes in this world.
  final StoryTheme theme;

  /// Up to two further flavours blended with [theme] in every episode. Editing
  /// these changes how future episodes are written.
  final List<StoryTheme> extraThemes;

  /// [theme] plus [extraThemes], in the order they were picked.
  List<StoryTheme> get allThemes => [theme, ...extraThemes];

  /// The voice that tells every story in this world. Empty means "whatever the
  /// grown-up chose in settings".
  ///
  /// A world is the thing a child recognises — the same place, the same
  /// friends — and a storyteller who changes between episodes breaks that more
  /// than a changed colour would. Only the voice *name* lives here, never the
  /// engine: engines need a key and a consent, which are a parent's business,
  /// while a voice is a name a child can choose by ear.
  ///
  /// Narration is cached per voice, so changing this leaves the episodes
  /// already recorded matching the old one. Nothing is lost — `SavedNarration`
  /// still finds them — but the next chapter is recorded afresh, which is why
  /// the picker says so out loud.
  final String voiceName;

  /// The look every picture in this world shares — palette, medium, light,
  /// line quality — written once from the world's own premise and then
  /// repeated verbatim in every image prompt.
  ///
  /// Text alone cannot pin a *character* down, which is what character sheets
  /// are for; but it pins the *world* down very well, and a world illustrated
  /// in one hand across twenty episodes is most of what makes it a place.
  final String styleGuide;

  /// Cast edits the next story still has to acknowledge (arrivals to introduce,
  /// departures to write out gently). Cleared once a chapter has used them.
  final CastChanges pendingCastChanges;

  World copyWith({
    String? name,
    String? premise,
    StoryTheme? theme,
    List<StoryTheme>? extraThemes,
    String? voiceName,
    String? styleGuide,
    CastChanges? pendingCastChanges,
  }) => World(
    id: id,
    childId: childId,
    name: name ?? this.name,
    premise: premise ?? this.premise,
    theme: theme ?? this.theme,
    extraThemes: extraThemes ?? this.extraThemes,
    voiceName: voiceName ?? this.voiceName,
    styleGuide: styleGuide ?? this.styleGuide,
    pendingCastChanges: pendingCastChanges ?? this.pendingCastChanges,
  );
}

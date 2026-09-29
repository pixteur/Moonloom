/// A saved, reusable character belonging to a [World] (e.g. "Splat, a big
/// black cat who loves adventures"). Selected when starting an episode so the
/// story stays consistent across the whole universe. See `docs/data-model.md`.
class StoryCharacter {
  const StoryCharacter({
    required this.id,
    required this.worldId,
    required this.name,
    this.description = '',
    this.sheetFileKey = '',
  });

  final String id;
  final String worldId;

  /// The character's name (e.g. "Splat").
  final String name;

  /// A short description of who they are, woven into the prompt.
  final String description;

  /// A reference drawing of this character, handed to the image model every
  /// time they appear. A description cannot pin a face down — "a small white
  /// fox" describes a thousand foxes, and the pictures proved it — so the
  /// drawing is the specification and the words are only the brief for it.
  final String sheetFileKey;

  StoryCharacter copyWith({
    String? name,
    String? description,
    String? sheetFileKey,
  }) => StoryCharacter(
    id: id,
    worldId: worldId,
    name: name ?? this.name,
    description: description ?? this.description,
    sheetFileKey: sheetFileKey ?? this.sheetFileKey,
  );

  /// One-line form for prompts, e.g. "Splat — a big black cat who loves...".
  String get promptLine =>
      description.trim().isEmpty ? name : '$name — ${description.trim()}';
}

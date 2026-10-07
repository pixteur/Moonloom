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
    this.voiceId = '',
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

  /// A voice of this character's own: a designed `voice_…` id, or empty for
  /// the narrator to play them. At most one character in a world has one —
  /// a voice request holds two speakers, the narrator and one other — and the
  /// child never does: the voice service refuses to design a child's voice,
  /// and an app for children should not want one.
  final String voiceId;

  bool get hasVoice => voiceId.trim().isNotEmpty;

  StoryCharacter copyWith({
    String? name,
    String? description,
    String? sheetFileKey,
    String? voiceId,
  }) => StoryCharacter(
    id: id,
    worldId: worldId,
    name: name ?? this.name,
    description: description ?? this.description,
    sheetFileKey: sheetFileKey ?? this.sheetFileKey,
    voiceId: voiceId ?? this.voiceId,
  );

  /// One-line form for prompts, e.g. "Splat — a big black cat who loves...".
  String get promptLine =>
      description.trim().isEmpty ? name : '$name — ${description.trim()}';
}

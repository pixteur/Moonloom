/// Direction for the narrator, written once by the editorial pass and rendered
/// differently by every voice engine.
///
/// The cardinal rule is that none of this ever goes inside the story text. That
/// same string is shown on screen, written into the Lunii pack and `.sleepy`
/// exports, and used as the audio-cache key — and an engine handed markup it
/// does not understand *reads it out loud*. A child hearing "bracket whispers
/// bracket" is worse than no direction at all.
///
/// So cues are **semantic, never syntactic**: `pace=slow`, not `<break>` or
/// `[whispers]`. Each adapter turns them into its own dialect — prose
/// `instructions` for OpenAI, a spoken-style prefix for Gemini, inline audio
/// tags for ElevenLabs v3, `voice_settings` for v2, rate and pitch for the
/// Windows voice — or ignores them. See `docs/narration-cues.md`.
library;

/// One paragraph's direction. Every field is optional; an empty cue means
/// "read this plainly", which is the right default for most of a story.
class NarrationCue {
  const NarrationCue({
    this.pace = '',
    this.emotion = '',
    this.volume = '',
    this.note = '',
  });

  /// Parse the `key=value; key=value` line the model returns. Unknown keys are
  /// dropped rather than rejected — a model inventing `intensity=high` should
  /// cost us that one hint, not the whole cue.
  factory NarrationCue.parse(String raw) {
    final fields = <String, String>{};
    for (final part in raw.split(';')) {
      final split = part.indexOf('=');
      if (split <= 0) continue;
      final key = part.substring(0, split).trim().toLowerCase();
      final value = part.substring(split + 1).trim();
      if (value.isNotEmpty) fields[key] = value;
    }
    return NarrationCue(
      pace: fields['pace'] ?? '',
      emotion: fields['emotion'] ?? '',
      volume: fields['volume'] ?? '',
      note: fields['note'] ?? '',
    );
  }

  /// How fast, e.g. `slow`, `unhurried`, `brisk`.
  final String pace;

  /// The feeling to colour it with, e.g. `wistful`, `delighted`, `curious`.
  final String emotion;

  /// How loud, e.g. `hushed`, `soft`, `warm`.
  final String volume;

  /// A free-text direction that can point inside the paragraph — "linger on
  /// the last line". This is where sub-paragraph shaping lives, because
  /// splitting a paragraph into one request per sentence makes every sentence
  /// restart its intonation and the reading turns choppy.
  final String note;

  bool get isEmpty =>
      pace.isEmpty && emotion.isEmpty && volume.isEmpty && note.isEmpty;

  /// The cue as a sentence a voice model can act on. Used directly by the
  /// providers that take natural-language direction.
  String asDirection() {
    final parts = <String>[
      if (pace.isNotEmpty) pace,
      if (volume.isNotEmpty) volume,
      if (emotion.isNotEmpty) emotion,
    ];
    final buffer = StringBuffer();
    if (parts.isNotEmpty) buffer.write(parts.join(', '));
    if (note.isNotEmpty) {
      if (parts.isNotEmpty) buffer.write('. ');
      buffer.write(note);
    }
    return buffer.toString();
  }

  /// Round-trips through [NarrationCue.parse]. This is what gets mixed into
  /// the audio-cache key: the cue changes the audio without changing a word of
  /// the text, so a key that ignored it would replay the old reading.
  String encode() => [
    if (pace.isNotEmpty) 'pace=$pace',
    if (emotion.isNotEmpty) 'emotion=$emotion',
    if (volume.isNotEmpty) 'volume=$volume',
    if (note.isNotEmpty) 'note=$note',
  ].join('; ');

  @override
  String toString() => encode();
}

/// Everything the editorial pass says about how a chapter should sound.
class NarrationNotes {
  const NarrationNotes({
    this.style = '',
    this.characterVoices = const [],
    this.cues = const [],
    this.speakers = const [],
  });

  /// One line covering the whole chapter — the voice to read it all in.
  /// Applies even where per-paragraph cues are unavailable or misaligned.
  final String style;

  /// How each character should sound in the narrator's mouth, e.g.
  /// `Leo — precise and warm, with a soft metallic edge`. A single narrator
  /// shifting tone travels across every engine, where true multi-speaker
  /// output does not, and it is gentler at bedtime than hard voice switches.
  final List<String> characterVoices;

  /// One cue per paragraph of the chapter, in order.
  final List<NarrationCue> cues;

  /// Who says each quoted line, as `Name: the first few words of the line`,
  /// one entry per line in order. Lets the hero speak in their own voice and
  /// the narrator act everyone else. Matched to lines by their words, never
  /// by position; see `attributeQuotes` in domain/performance.dart.
  final List<String> speakers;

  bool get isEmpty =>
      style.isEmpty &&
      characterVoices.isEmpty &&
      cues.every((c) => c.isEmpty) &&
      speakers.every((s) => s.trim().isEmpty);

  /// Stored as one JSON blob on the beat rather than three columns — this is
  /// direction for the voice, never queried, and it travels as a unit.
  Map<String, dynamic> toJson() => {
    'style': style,
    'voices': characterVoices,
    'cues': [for (final c in cues) c.encode()],
    'speakers': speakers,
  };

  static NarrationNotes fromJson(Map<String, dynamic> json) => NarrationNotes(
    style: (json['style'] as String?) ?? '',
    characterVoices: [
      for (final v in (json['voices'] as List<dynamic>? ?? const []))
        v.toString(),
    ],
    cues: [
      for (final c in (json['cues'] as List<dynamic>? ?? const []))
        NarrationCue.parse(c.toString()),
    ],
    speakers: [
      for (final s in (json['speakers'] as List<dynamic>? ?? const []))
        s.toString(),
    ],
  );

  /// The cue for paragraph [index], or an empty cue when the model returned
  /// the wrong number of them. Misalignment must degrade to "read it plainly",
  /// never to reading paragraph 4 with paragraph 9's direction.
  NarrationCue cueAt(int index) =>
      index >= 0 && index < cues.length ? cues[index] : const NarrationCue();

  /// The standing direction every paragraph inherits: the chapter's voice plus
  /// the character voices, without any one paragraph's cue.
  String asStandingDirection() {
    final buffer = StringBuffer();
    if (style.isNotEmpty) buffer.write(style);
    if (characterVoices.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('Voice the characters: ${characterVoices.join('; ')}.');
    }
    return buffer.toString();
  }

  /// Full direction for one paragraph — the standing direction plus that
  /// paragraph's cue. This is the string the instruction-taking providers send.
  String directionFor(int index) {
    final standing = asStandingDirection();
    final cue = cueAt(index).asDirection();
    if (cue.isEmpty) return standing;
    if (standing.isEmpty) return cue;
    return '$standing For this passage: $cue.';
  }
}

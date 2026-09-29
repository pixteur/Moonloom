/// A picture belonging to a story.
///
/// Two things travel with every image, and the reason is the same one:
/// **the picture itself cannot be regenerated.** Asking the model for the same
/// prompt with the same seed twice gives two different pictures — measured, in
/// `tool/image_probe.dart` — so a book reprinted from a stored recipe would
/// not be the book the child knows. The bytes on disk are the artefact; the
/// prompt is provenance.
///
/// Which is not to say the prompt is worthless. It lets a parent ask for
/// *another* picture of the same scene, lets a lost file be redrawn, and lets
/// the whole library be re-rendered if a much better model arrives — including,
/// one day, in layers, so a still can be given a little parallax. None of that
/// works if the prompt was thrown away. See `docs/story-images.md`.
library;

/// What a picture is for. Each kind is composed differently, not just placed
/// differently: a cover leaves room for a title, a Lunii frame is drawn flat
/// so it survives sixteen colours.
enum StoryImageKind {
  /// The story's poster. Portrait, with a calm upper third for the title,
  /// which is set in vector over it rather than drawn into it — stories rename
  /// themselves after the first chapter, and a baked-in title would mean
  /// paying to redraw the cover each time.
  cover,

  /// One chapter's picture, shown above its words.
  chapter,

  /// A flat, high-contrast version for the storyteller device, which takes
  /// 320×240 in sixteen colours and turns a painterly image into mud.
  lunii,

  /// A reference drawing of one character — three views, plain background,
  /// even light — handed back to the model every time that character appears.
  /// Never shown to a child: this is a specification, not a picture.
  characterSheet,
}

class StoryImage {
  const StoryImage({
    required this.id,
    required this.seriesId,
    required this.kind,
    required this.fileKey,
    required this.prompt,
    this.beatId,
    this.seed,
    this.model = '',
    this.size = '2K',
    this.aspect = '4:3',
    this.createdAt,
  });

  final String id;
  final String seriesId;

  /// Null for a cover: it belongs to the story, not to any one chapter.
  final String? beatId;

  final StoryImageKind kind;

  /// Content-addressed name of the bytes on disk. Images never live in the
  /// database — the same reason narration does not.
  final String fileKey;

  /// What was asked for. Kept as provenance; see the library doc above.
  final String prompt;

  /// What was asked for alongside it. Recorded honestly even though the model
  /// does not honour it, so a later model that does can be told what we meant.
  final int? seed;

  final String model;
  final String size;
  final String aspect;
  final DateTime? createdAt;

  StoryImage copyWith({String? fileKey, String? prompt}) => StoryImage(
    id: id,
    seriesId: seriesId,
    beatId: beatId,
    kind: kind,
    fileKey: fileKey ?? this.fileKey,
    prompt: prompt ?? this.prompt,
    seed: seed,
    model: model,
    size: size,
    aspect: aspect,
    createdAt: createdAt,
  );
}

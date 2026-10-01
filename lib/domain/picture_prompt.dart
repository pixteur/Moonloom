/// Turning a finished chapter into a request for a picture.
///
/// Pure, like the story prompts, and for the same reason: this is the one
/// place that decides what the image model is asked for, so it can be read and
/// tested without a network.
///
/// **It draws from the edited chapter, never from what a child typed.** The
/// setting and characters fields the editorial pass fills in are already safe,
/// already on-model, and already consistent across a series — a story idea
/// typed into a text box is none of those things, and is the one input in the
/// whole app a child controls directly. Keeping it out of the image model is a
/// safety property first and a consistency win second.
library;

import 'cast_line.dart';
import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_image.dart';

/// The fallback house style, used only by a world that has not been given one.
const String _house =
    'Soft painterly children\'s picture-book illustration, warm and gentle, '
    'rounded shapes, calm bedtime mood, safe and cosy. No text, letters, '
    'numbers or writing anywhere in the image.';

/// The look this world is drawn in, falling back to the house style.
///
/// A world's own guide is written once from its premise, then repeated
/// **verbatim** in every prompt. Verbatim matters: paraphrasing it per picture
/// is how a series ends up looking like twenty artists took a chapter each.
String styleFor(String? styleGuide) {
  final own = styleGuide?.trim() ?? '';
  return own.isEmpty ? _house : own;
}

/// Ask the story model to design the world's look.
///
/// The writer already knows the arc, the setting and the mood, which is
/// exactly the brief an art director would work from — so it writes the art
/// direction rather than having a second model guess at it from a title.
String styleGuideBrief({
  required String worldName,
  required String premise,
  required String themes,
}) =>
    'You are the art director for a children\'s picture-book series called '
    '"$worldName". $premise The stories lean towards: $themes.\n\n'
    'Write ONE paragraph of art direction, 50 to 70 words, describing the '
    'look every illustration in this series will share. Cover: the medium and '
    'finish, the palette in concrete colour words, the quality of light, the '
    'line and edge treatment, and the overall mood. Be specific enough that '
    'two different illustrators would produce pictures that sit together in '
    'the same book.\n\n'
    'It must suit a calm bedtime story for a young child: warm, safe, never '
    'harsh or frightening. Describe only the style — no characters, no scene, '
    'no story. Write it as a direct instruction to an illustrator, with no '
    'preamble and no heading.';

/// The brief for one character's reference sheet.
///
/// Drawn to be *referred to* rather than looked at: plain background, even
/// light, no scene, nothing competing. The sheet is the specification a later
/// scene is measured against, and anything decorative in it becomes noise the
/// model has to ignore.
String characterSheetPrompt(
  String name,
  String description, {
  String? styleGuide,
}) =>
    '${styleFor(styleGuide)}\n\n'
    'A character reference sheet. The same character shown three times '
    'against a plain flat cream background: front view, three-quarter view, '
    'and side view, standing, full body, evenly lit, neutral expression. '
    'Identical colours, markings and proportions in all three. '
    'The character is $name${description.trim().isEmpty ? '' : ': '
              '${description.trim()}'}. '
    'No scene, no background detail, no props beyond what the character '
    'wears or carries. No text, labels, letters or writing anywhere.';

/// How to tell the model to obey the reference drawings it was handed.
///
/// Named in order, because with two references "the first" and "the second"
/// is the only handle there is — and the order has to match the order the
/// images were attached.
String referenceClause(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) {
    return 'The reference image shows ${names.first}. Draw them exactly as '
        'drawn there — same colours, same markings, same proportions. ';
  }
  final labelled = <String>[];
  for (var i = 0; i < names.length; i++) {
    labelled.add(
      '${i == 0 ? 'The first' : 'the ${_ordinal(i + 1)}'} '
      'reference image shows ${names[i]}',
    );
  }
  return '${labelled.join('; ')}. Draw each of them exactly as drawn there — '
      'same colours, same markings, same proportions. ';
}

String _ordinal(int n) => switch (n) {
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  _ => '${n}th',
};

/// The look a Lunii can actually show: sixteen flat colours at 320×240 turn a
/// painting into mud, so the picture has to be built out of shapes big enough
/// to survive it.
const String _flat =
    'Bold flat picture-book illustration in the style of a silkscreen poster. '
    'Large simple shapes, thick clean outlines, high contrast, a limited '
    'palette of about six flat colours, no gradients, no texture, no fine '
    'detail, no small elements. Designed to stay readable when reduced to '
    'sixteen colours at low resolution. No text, letters or writing.';

/// What the picture should be of, drawn from the chapter itself.
String _scene(Beat beat) {
  final parts = <String>[
    if (beat.setting.trim().isNotEmpty) beat.setting.trim(),
    if (beat.characters.isNotEmpty)
      'Featuring ${beat.characters.take(3).join(', ')}',
  ];
  // The summary is one line the editor wrote about what happens, which is a
  // better brief than the prose: it is already the gist, already spoiler-free
  // enough for an opening picture, and short enough not to swamp the style.
  if (beat.summary.trim().isNotEmpty) parts.add(beat.summary.trim());
  return parts.join('. ');
}

/// The cast a world carries, so the same fox looks like the same fox in every
/// episode. Capped, because a long list stops steering and starts crowding.
String _cast(List<String> cast) => cast.isEmpty
    ? ''
    : ' Keep these characters consistent and recognisable: '
          '${cast.take(4).join('; ')}.';

/// A picture for one chapter.
String chapterPicturePrompt(
  Beat beat, {
  List<String> cast = const [],
  List<String> references = const [],
  String? styleGuide,
}) =>
    '${styleFor(styleGuide)}\n\n'
    '${referenceClause(references)}'
    'A scene from a bedtime story: ${_scene(beat)}.${_cast(cast)} '
    'Show one clear moment rather than several. Leave the mood calm and '
    'unfrightening even if the story has a problem in it.';

/// The story's poster.
///
/// Composed for a title to be set over it in vector afterwards, never drawn
/// into the image: stories name themselves once the first chapter exists and
/// can be renamed later, so lettering baked into the art would mean paying to
/// redraw the cover every time the name changed — besides being unreliable to
/// spell and mush at print size.
String coverPicturePrompt(
  Series series,
  Beat opening, {
  List<String> cast = const [],
  List<String> references = const [],
  String? styleGuide,
}) =>
    '${styleFor(styleGuide)}\n\n'
    '${referenceClause(references)}'
    'A storybook cover in the style of a warm film poster, portrait. '
    'The main characters stand together in the lower two thirds, looking out '
    'at the reader: ${_scene(opening)}.${_cast(cast)} '
    'The upper third is calm, uncluttered sky or space with no detail in it, '
    'left deliberately empty so a title can be placed over it later. '
    'Inviting, the kind of cover a child would pick off a shelf.';

/// The same story, drawn so the storyteller device can show it.
///
/// The world's style guide is deliberately *not* used here. It describes a
/// painterly look the device cannot show — sixteen flat colours at 320×240
/// turn a painting into mud — so this keeps its own flat brief. The character
/// references still apply: the fox should stay the same fox even in silhouette.
String luniiPicturePrompt(
  Series series,
  Beat opening, {
  List<String> references = const [],
  String? subject,
}) {
  // A portrait, not a scene.
  //
  // The device shows one still picture for a whole story, on a screen the size
  // of a postage stamp, and a child picks a pack by looking at it. A scene
  // reduced to 320×240 in sixteen colours becomes a smudge with weather in it;
  // one face, filling the frame, survives — and survives being glanced at
  // across a room, which is how it is actually used.
  //
  // It also gives each story in a world a different picture, which the
  // procedural cover could never do: that is seeded on the world's name, so
  // every episode of Pip's Adventures looked identical on the shelf.
  final who = subject?.trim() ?? '';
  return '$_flat\n\n'
      '${referenceClause(references)}'
      '${who.isEmpty ? 'A portrait of the main character of this bedtime '
                'story: ${_scene(opening)}' : 'A portrait of $who, a character '
                'from a bedtime story'}. '
      'Head and shoulders, facing the viewer, filling most of the frame, '
      'against a plain background of a single flat colour. Friendly and calm. '
      'One character only — nobody else in the picture, no scenery, no props.';
}

/// The prompt for a picture of [kind].
String picturePromptFor(
  StoryImageKind kind,
  Series series,
  Beat beat, {
  List<String> cast = const [],
  List<String> references = const [],
  String? styleGuide,
}) => switch (kind) {
  StoryImageKind.cover => coverPicturePrompt(
    series,
    beat,
    cast: cast,
    references: references,
    styleGuide: styleGuide,
  ),
  StoryImageKind.chapter => chapterPicturePrompt(
    beat,
    cast: cast,
    references: references,
    styleGuide: styleGuide,
  ),
  StoryImageKind.lunii => luniiPicturePrompt(
    series,
    beat,
    references: references,
  ),
  StoryImageKind.characterSheet => characterSheetPrompt(
    beat.title,
    beat.summary,
    styleGuide: styleGuide,
  ),
};

/// Which character this story's device picture should be a portrait of.
///
/// Different story, different face — that is the whole point, since the
/// procedural cover is seeded on the world's name and gives every episode in a
/// world the same picture. But **stable** for a given story: re-sending a pack
/// must not redraw it, or a child's shelf rearranges itself between sends.
///
/// Chosen from the characters this story actually mentions, so a portrait is
/// of somebody who is in it. Falling back to the whole cast when the story
/// names nobody is deliberate — a face from the right world beats no face.
String? portraitSubject({
  required String seriesId,
  required List<String> cast,
  required List<Beat> beats,
}) {
  if (cast.isEmpty) return null;
  final mentioned = cast.where((line) {
    final name = parseCastEntry(line).$1.toLowerCase();
    if (name.isEmpty) return false;
    return beats.any(
      (b) =>
          b.characters.join(' ').toLowerCase().contains(name) ||
          b.summary.toLowerCase().contains(name),
    );
  }).toList();

  final candidates = mentioned.isEmpty ? cast : mentioned;
  // FNV-1a over the story's id: stable for this story, and spread across the
  // cast between stories. A counter would need somewhere to live and would
  // drift the moment a story was deleted.
  var hash = 0x811c9dc5;
  for (final c in seriesId.codeUnits) {
    hash = ((hash ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return candidates[hash % candidates.length];
}

/// Which chapters of a story get a picture.
///
/// Restrained on purpose, and not only for cost. A child looking at a picture
/// is not listening to the story, and one every few paragraphs turns a reading
/// into a picture book being flicked through. A week-long story gets three —
/// beginning, middle, end — and everything shorter gets less.
List<int> chaptersToIllustrate(int chapterCount) {
  if (chapterCount <= 1) return const [];
  if (chapterCount <= 4) return [chapterCount ~/ 2];
  return [0, chapterCount ~/ 2, chapterCount - 1];
}

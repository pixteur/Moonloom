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

import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_image.dart';

/// A house style every picture shares, so a series looks like one book.
const String _house =
    'Soft painterly children\'s picture-book illustration, warm and gentle, '
    'rounded shapes, calm bedtime mood, safe and cosy. No text, letters, '
    'numbers or writing anywhere in the image.';

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
String chapterPicturePrompt(Beat beat, {List<String> cast = const []}) =>
    '$_house A scene from a bedtime story: ${_scene(beat)}.${_cast(cast)} '
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
}) =>
    '$_house A storybook cover in the style of a warm film poster, portrait. '
    'The main characters stand together in the lower two thirds, looking out '
    'at the reader: ${_scene(opening)}.${_cast(cast)} '
    'The upper third is calm, uncluttered sky or space with no detail in it, '
    'left deliberately empty so a title can be placed over it later. '
    'Inviting, the kind of cover a child would pick off a shelf.';

/// The same story, drawn so the storyteller device can show it.
String luniiPicturePrompt(Series series, Beat opening) =>
    '$_flat A scene from a bedtime story: ${_scene(opening)}. '
    'One or two characters only, large in the frame, against a simple '
    'background.';

/// The prompt for a picture of [kind].
String picturePromptFor(
  StoryImageKind kind,
  Series series,
  Beat beat, {
  List<String> cast = const [],
}) => switch (kind) {
  StoryImageKind.cover => coverPicturePrompt(series, beat, cast: cast),
  StoryImageKind.chapter => chapterPicturePrompt(beat, cast: cast),
  StoryImageKind.lunii => luniiPicturePrompt(series, beat),
};

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

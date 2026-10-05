import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/series.dart';
import 'package:moonloom/domain/picture_prompt.dart';

/// Who the storyteller's picture is of.
///
/// Two properties, pulling against each other, and both of them matter on a
/// shelf of packs rather than in the app:
///
///   * **Different between stories.** The picture before this was seeded on the
///     world's name, so every episode of one world was the same picture and a
///     child could not tell them apart.
///   * **The same within one story.** Re-sending a pack must not redraw it.
///     A shelf that rearranges itself between sends is worse than a dull one.
void main() {
  Beat beat(String id, {String characters = 'Pip', String summary = ''}) =>
      Beat(
        id: id,
        seriesId: 's1',
        childId: 'c1',
        seq: 0,
        intent: StoryIntent.continued,
        text: 'Some words.',
        summary: summary,
        title: 'Chapter one',
        rating: AgeRating.tiny,
        setting: 'a shallow reef',
        characters: characters.split(','),
      );

  const cast = [
    'Pip — an axolotl',
    'Bolt — a small silver robot',
    'Lumina — an ocean dragon',
    'Barnaby — a hermit crab',
  ];

  test('holds still for one story', () {
    final beats = [beat('b1', characters: 'Pip,Bolt')];
    final once = portraitSubject(seriesId: 's1', cast: cast, beats: beats);
    final again = portraitSubject(seriesId: 's1', cast: cast, beats: beats);
    expect(once, same(again));
  });

  test('varies between stories in the same world', () {
    final beats = [beat('b1', characters: 'Pip,Bolt,Lumina,Barnaby')];
    final picked = {
      for (final id in [
        '0f0d6c3e',
        'a11c2b9d',
        '7731ee40',
        'c0ffee12',
        '55aa33bb',
        'deadbeef',
      ])
        portraitSubject(seriesId: id, cast: cast, beats: beats),
    };
    expect(
      picked.length,
      greaterThan(1),
      reason: 'six episodes of one world must not all wear one face',
    );
  });

  // The point of picking from the story rather than the world: the device
  // showing a character who is nowhere in the story is the drift the whole
  // character-sheet apparatus exists to stop.
  test('only somebody the story mentions', () {
    final subject = portraitSubject(
      seriesId: 'whatever',
      cast: cast,
      beats: [beat('b1', characters: 'Lumina')],
    );
    expect(subject, 'Lumina — an ocean dragon');
  });

  test('a name in the summary counts as mentioned', () {
    final subject = portraitSubject(
      seriesId: 'whatever',
      cast: cast,
      beats: [
        beat('b1', characters: 'nobody in the cast', summary: 'Bolt waits.'),
      ],
    );
    expect(subject, 'Bolt — a small silver robot');
  });

  // A face from the right world beats no face: the fallback is deliberate, not
  // an oversight. A story whose beats name nobody still gets a picture.
  test('falls back to the whole cast when the story names nobody', () {
    final subject = portraitSubject(
      seriesId: 's1',
      cast: cast,
      beats: [beat('b1', characters: 'a passing gull')],
    );
    expect(cast, contains(subject));
  });

  test('no cast, no portrait', () {
    expect(
      portraitSubject(seriesId: 's1', cast: const [], beats: [beat('b1')]),
      isNull,
    );
  });

  // No beats is the extreme of "names nobody", not a separate case: the same
  // fallback applies. Nothing calls it that way — `ensureLuniiPortrait`
  // returns before this on an empty story, since the prompt needs a chapter to
  // describe — but it answers rather than throwing.
  test('no beats falls back to the cast rather than failing', () {
    expect(
      cast,
      contains(portraitSubject(seriesId: 's1', cast: cast, beats: const [])),
    );
  });

  group('the prompt it produces', () {
    const series = Series(
      id: 's1',
      childId: 'c1',
      title: 'The Ancient Sea Knot',
      theme: StoryTheme.cozy,
    );

    test('asks for one face, filling the frame, on a flat background', () {
      final prompt = luniiPicturePrompt(
        series,
        beat('b1'),
        subject: 'Pip — an axolotl',
      );
      expect(prompt, contains('A portrait of Pip — an axolotl'));
      expect(prompt, contains('filling most of the frame'));
      expect(prompt, contains('single flat colour'));
      expect(prompt, contains('One character only'));
    });

    // Anything the device shows has to survive sixteen colours at 320×240, so
    // this prompt keeps its own flat brief rather than the world's painterly
    // style guide. A painted portrait arrives as mud.
    test('never carries a painterly style guide', () {
      final prompt = luniiPicturePrompt(series, beat('b1'), subject: 'Pip');
      expect(prompt, contains('flat'));
      expect(prompt, contains('sixteen colours'));
      expect(prompt, isNot(contains('watercolour')));
    });

    test('with no subject it still asks for a portrait', () {
      final prompt = luniiPicturePrompt(series, beat('b1'));
      expect(prompt, contains('A portrait of the main character'));
    });

    test('a reference is named so the model knows who it shows', () {
      final prompt = luniiPicturePrompt(
        series,
        beat('b1'),
        references: const ['Pip'],
        subject: 'Pip — an axolotl',
      );
      expect(prompt, contains('reference image shows Pip'));
    });
  });

  // One cover and one picture per chapter, as asked — every night of a week
  // has a picture of its own. Change `chaptersPerPicture` to draw fewer.
  group('which chapters get a picture', () {
    test('every chapter of a week', () {
      expect(chaptersToIllustrate(7), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('a mini episode gets its one chapter drawn', () {
      expect(chaptersToIllustrate(1), [0]);
    });

    test('an empty story gets none', () {
      expect(chaptersToIllustrate(0), isEmpty);
    });
  });
}

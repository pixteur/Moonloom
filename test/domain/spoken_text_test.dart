import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/domain/spoken_text.dart';

void main() {
  // Every one of these came out of the real library via
  // `tool/prose_check.dart`. They are the whole reason this exists: the
  // prompt forbids markup twice and four saved chapters have it anyway,
  // each one a foreign word the model wanted to lean on.
  group('markup that was actually saved', () {
    test('emphasis around a foreign word keeps the word', () {
      expect(
        stripSpokenMarkup(
          'something that glitters, something truly '
          '*brillant*."',
        ),
        'something that glitters, something truly brillant."',
      );
    });

    test('and again, mid-sentence, in the other direction', () {
      expect(
        stripSpokenMarkup("Le premier *snow* de l'année était tombé,"),
        "Le premier snow de l'année était tombé,",
      );
    });

    test('accents survive, because they are letters', () {
      expect(
        stripSpokenMarkup('It looks like a *petit nœud*!'),
        'It looks like a petit nœud!',
      );
    });

    test('and the one with a comparison in it', () {
      expect(
        stripSpokenMarkup('these dots, like tiny *hoshi*, little stars'),
        'these dots, like tiny hoshi, little stars',
      );
    });
  });

  group('what else a voice would have read out', () {
    test('a bracketed direction goes entirely', () {
      expect(
        stripSpokenMarkup('[whispers] The moon was low.'),
        'The moon was low.',
      );
    });

    test('an unpaired asterisk goes too', () {
      expect(stripSpokenMarkup('The fox * paused.'), 'The fox paused.');
    });

    test('double emphasis unwraps completely', () {
      expect(stripSpokenMarkup('It was **very** quiet.'), 'It was very quiet.');
    });

    test('no space is left in front of punctuation', () {
      expect(stripSpokenMarkup('She smiled *softly* .'), 'She smiled softly.');
    });
  });

  group('what it must not touch', () {
    test('quotation marks and parentheses are punctuation, not formatting', () {
      const line = '"Come along," said Pip (who was already ahead).';
      expect(stripSpokenMarkup(line), line);
    });

    test('accents, guillemets and dashes are left exactly as written', () {
      const line = '« Léo, est-ce que nous sommes bientôt arrivés ? »';
      expect(stripSpokenMarkup(line), line);
    });

    test('the blank line between paragraphs survives, because chunking reads '
        'it', () {
      const chapter = 'First paragraph.\n\nSecond paragraph.';
      expect(stripSpokenMarkup(chapter), chapter);
    });

    test('a lone underscore inside a word is left alone', () {
      // Not prose we expect, but stripping it would corrupt the word rather
      // than tidy it, and a wrong fix is worse than the mark.
      expect(stripSpokenMarkup('file_name'), 'file_name');
    });

    test('a plain chapter is returned unchanged', () {
      const chapter =
          'Crystal lifted the lantern.\n\nThe whole meadow turned gold, and '
          'the crickets went quiet for a moment.';
      expect(stripSpokenMarkup(chapter), chapter);
    });
  });

  test('running it twice changes nothing more', () {
    const messy = 'A *petit nœud* [softly] and a stray * mark.';
    final once = stripSpokenMarkup(messy);
    expect(stripSpokenMarkup(once), once);
  });

  test('an empty chapter does not throw', () {
    expect(stripSpokenMarkup(''), '');
  });
}

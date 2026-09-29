import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/cast_line.dart';

void main() {
  // Every one of these came out of the real library. The model writes a cast
  // list in whatever shape it fancies, and the first parser understood two of
  // the four — which is how a world ended up with a Pip, a "Pip (axolotl)"
  // and a "Pip: an axolotl", none of whom were each other.
  group('the shapes a model actually writes', () {
    test('a comma', () {
      expect(parseCastEntry('Pip, an axolotl'), ('Pip', 'an axolotl'));
    });

    test('an em dash', () {
      expect(parseCastEntry('Bolt — a small silver robot'), (
        'Bolt',
        'a small silver robot',
      ));
    });

    test('brackets', () {
      expect(parseCastEntry('Pip (axolotl)'), ('Pip', 'axolotl'));
    });

    test('a colon', () {
      expect(parseCastEntry('Lumina: an ocean dragon'), (
        'Lumina',
        'an ocean dragon',
      ));
    });

    test('brackets holding a comma of their own', () {
      // Splitting on the comma first would cut the description in half and
      // leave "Bolt (robot" as somebody's name.
      expect(parseCastEntry("Bolt (robot, Leo's companion)"), (
        'Bolt',
        "robot, Leo's companion",
      ));
    });

    test('a name with nothing after it', () {
      expect(parseCastEntry('Coral'), ('Coral', ''));
    });

    test('a spaced hyphen, but not a hyphenated name', () {
      expect(parseCastEntry('Lumi - a sea dragon'), ('Lumi', 'a sea dragon'));
      expect(parseCastEntry('Jean-Luc'), ('Jean-Luc', ''));
    });

    test('French, which the bilingual stories produce', () {
      expect(parseCastEntry('Elodie (une fille 8 ans)'), (
        'Elodie',
        'une fille 8 ans',
      ));
    });
  });

  group('what it refuses', () {
    test('an empty entry', () {
      expect(parseCastEntry(''), ('', ''));
      expect(parseCastEntry('   '), ('', ''));
    });

    test('a description that lost its name', () {
      expect(parseCastEntry('— a small robot').$1, isEmpty);
    });

    test('a sentence pretending to be a name', () {
      // Storing this would put a paragraph into every future prompt.
      expect(
        parseCastEntry(
          'Barnaby the leopard shark pup who lives in the kelp forest',
        ).$1,
        isEmpty,
      );
    });

    test('a very long description is cut, not dropped', () {
      final long = 'a ${'very ' * 80}old turtle';
      final (name, description) = parseCastEntry('Coral, $long');
      expect(name, 'Coral');
      expect(description.length, lessThanOrEqualTo(201));
      expect(description, endsWith('…'));
    });
  });

  group('tidying', () {
    test('quotes around a name are dropped', () {
      expect(parseCastEntry('"Pip", an axolotl'), ('Pip', 'an axolotl'));
    });

    test('a trailing full stop is dropped from the description', () {
      expect(parseCastEntry('Pip, an axolotl.'), ('Pip', 'an axolotl'));
    });
  });

  group('the same character, written differently', () {
    test('three shapes of Pip are one Pip', () {
      expect(sameCharacter('Pip', 'Pip (axolotl)'), isTrue);
      expect(sameCharacter('Pip, an axolotl', 'Pip: an axolotl'), isTrue);
      expect(sameCharacter('pip', 'Pip — an axolotl'), isTrue);
    });

    test('two different people are not', () {
      expect(sameCharacter('Pip, an axolotl', 'Coral, a turtle'), isFalse);
    });
  });
}

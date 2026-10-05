import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:moonloom/domain/performance.dart';

/// Who says each stretch of a chapter, and how.
///
/// The property everything else rests on comes first: the parts join back
/// into exactly the text on screen. A performance that dropped, doubled or
/// reworded a single character would put words in a child's ears that are not
/// on the page.
void main() {
  const voices = ['Pip — bright and bubbly', 'Barnaby — slow, gruff and kind'];

  String joined(List<SpeechPart> parts) => parts.map((p) => p.text).join();

  group('the words are the words', () {
    const chapter =
        'Pip swam up to the glass. "Look!" he said.\n\n'
        'Barnaby rumbled, "It is only the moon." Pip giggled.\n\n'
        'And the night was quiet.';

    test('every part joined is the text, character for character', () {
      final parts = performParagraphs(
        chapter,
        speakers: const ['Pip', 'Barnaby', ''],
        characterVoices: voices,
        heroName: 'Pip',
      );
      expect(joined(parts), chapter);
    });

    test('still exact when nothing is attributed at all', () {
      expect(joined(performParagraphs(chapter)), chapter);
    });

    test('still exact with an unclosed quote', () {
      const broken = 'Pip said, "Wait for me\n\nThe end.';
      expect(joined(performParagraphs(broken, heroName: 'Pip')), broken);
    });

    test('curly and French quotes are dialogue too', () {
      const mixed = 'Pip: “Bonjour!” Then «Au revoir!»';
      final parts = performParagraphs(
        mixed,
        speakers: const ['Pip, Pip'],
        heroName: 'Pip',
      );
      expect(joined(parts), mixed);
      expect(parts.where((p) => p.voice == PartVoice.hero).map((p) => p.text), [
        '“Bonjour!”',
        '«Au revoir!»',
      ]);
    });
  });

  group('who speaks', () {
    test("the hero's own lines go to the hero's voice", () {
      final parts = performParagraphs(
        'Pip swam up. "Look!" he said.',
        speakers: const ['Pip'],
        heroName: 'Pip',
      );
      expect(parts.map((p) => p.voice), [
        PartVoice.narrator,
        PartVoice.hero,
        PartVoice.narrator,
      ]);
      expect(parts[1].text, '"Look!"');
    });

    test('everyone else is the narrator, acting', () {
      final parts = performParagraphs(
        'Barnaby rumbled, "It is only the moon."',
        speakers: const ['Barnaby'],
        characterVoices: voices,
        heroName: 'Pip',
      );
      final line = parts.firstWhere((p) => p.text.contains('moon'));
      expect(line.voice, PartVoice.narrator);
      expect(line.style, contains('voicing Barnaby'));
      expect(line.style, contains('gruff'));
    });

    // When the child is the hero there is no hero voice: the voice service
    // refuses to design a child's voice, and the app should not want one.
    test('with no hero voice, the narrator reads every line', () {
      final parts = performParagraphs(
        'Mia laughed. "Again!"',
        speakers: const ['Mia'],
      );
      expect(parts.every((p) => p.voice == PartVoice.narrator), isTrue);
    });

    // A line in the wrong voice is worse than an unacted one, so a count that
    // does not add up is treated as no attribution at all.
    test('a speaker count that does not match the quotes is ignored', () {
      final parts = performParagraphs(
        '"One," said Pip. "Two," said Barnaby.',
        speakers: const ['Pip'], // two quotes, one name
        characterVoices: voices,
        heroName: 'Pip',
      );
      expect(parts.every((p) => p.voice == PartVoice.narrator), isTrue);
      expect(parts.any((p) => p.style.contains('voicing')), isFalse);
    });

    test('names match however they are written', () {
      final parts = performParagraphs(
        '"Coucou!"',
        speakers: const ['coeur'],
        characterVoices: const ['Cœur — a soft blue dragon'],
      );
      expect(parts.single.style, contains('voicing Cœur'));
    });
  });

  group('how it is delivered', () {
    test("narration carries the chapter's voice and the paragraph's cue", () {
      final parts = performParagraphs(
        'The moon rose.',
        cues: const [NarrationCue(pace: 'slow', volume: 'hushed')],
        standingStyle: 'warm and unhurried',
      );
      expect(parts.single.style, contains('warm and unhurried'));
      expect(parts.single.style, contains('slow'));
      expect(parts.single.style, contains('hushed'));
    });

    test('each paragraph keeps its own cue', () {
      final parts = performParagraphs(
        'A storm.\n\nThen calm.',
        cues: const [
          NarrationCue(emotion: 'excited'),
          NarrationCue(emotion: 'sleepy'),
        ],
      );
      expect(parts, hasLength(2));
      expect(parts[0].style, contains('excited'));
      expect(parts[1].style, contains('sleepy'));
    });

    test('a paragraph break never becomes a part of its own', () {
      final parts = performParagraphs(
        'One.\n\nTwo.',
        cues: const [
          NarrationCue(emotion: 'a'),
          NarrationCue(emotion: 'b'),
        ],
      );
      expect(parts.every((p) => p.text.trim().isNotEmpty), isTrue);
    });

    test('neighbouring parts in the same voice and tone are merged', () {
      final parts = performParagraphs('One.\n\nTwo.\n\nThree.');
      expect(parts, hasLength(1));
    });
  });
}

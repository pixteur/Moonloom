import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/narration.dart';

void main() {
  group('NarrationCue', () {
    test('parses the key=value line the model returns', () {
      final cue = NarrationCue.parse(
        'pace=slow; emotion=wistful; volume=hushed; note=linger on the last line',
      );
      expect(cue.pace, 'slow');
      expect(cue.emotion, 'wistful');
      expect(cue.volume, 'hushed');
      expect(cue.note, 'linger on the last line');
    });

    test('a blank entry means read it plainly', () {
      expect(NarrationCue.parse('').isEmpty, isTrue);
      expect(NarrationCue.parse('   ').isEmpty, isTrue);
    });

    test('an invented key costs that hint, not the whole cue', () {
      final cue = NarrationCue.parse('pace=slow; intensity=high; emotion=calm');
      expect(cue.pace, 'slow');
      expect(cue.emotion, 'calm');
      expect(cue.isEmpty, isFalse);
    });

    test('survives sloppy spacing and casing', () {
      final cue = NarrationCue.parse('  PACE = brisk ;  Emotion=delighted ');
      expect(cue.pace, 'brisk');
      expect(cue.emotion, 'delighted');
    });

    test('reads back as a direction a voice model can act on', () {
      const cue = NarrationCue(
        pace: 'slow',
        emotion: 'wistful',
        volume: 'hushed',
        note: 'linger on the last line',
      );
      expect(
        cue.asDirection(),
        'slow, hushed, wistful. linger on the last line',
      );
    });

    test('round-trips through encode so it can key the audio cache', () {
      const cue = NarrationCue(pace: 'slow', note: 'soften the ending');
      final again = NarrationCue.parse(cue.encode());
      expect(again.pace, cue.pace);
      expect(again.note, cue.note);
      expect(again.encode(), cue.encode());
    });
  });

  group('NarrationNotes', () {
    const notes = NarrationNotes(
      style: 'Unhurried and close, like a parent at the bedside.',
      characterVoices: ['Leo — precise and warm, with a soft metallic edge'],
      cues: [
        NarrationCue(pace: 'gentle'),
        NarrationCue(pace: 'slow', emotion: 'sleepy'),
      ],
    );

    test('a paragraph gets its own cue on top of the standing direction', () {
      final direction = notes.directionFor(1);
      expect(direction, contains('parent at the bedside'));
      expect(direction, contains('Leo — precise'));
      expect(direction, contains('slow, sleepy'));
    });

    test('a miscounted cue list degrades to plain reading, never to a '
        'neighbour\'s cue', () {
      // The model returned two cues for a chapter with more paragraphs.
      expect(notes.cueAt(7).isEmpty, isTrue);
      final direction = notes.directionFor(7);
      expect(direction, contains('parent at the bedside'));
      expect(direction, isNot(contains('sleepy')));
    });

    test('a negative index is treated as absent rather than throwing', () {
      expect(notes.cueAt(-1).isEmpty, isTrue);
    });

    test('empty notes are empty even with blank cues present', () {
      const blank = NarrationNotes(cues: [NarrationCue(), NarrationCue()]);
      expect(blank.isEmpty, isTrue);
    });
  });
}

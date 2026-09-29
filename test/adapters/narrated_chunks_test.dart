import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/narrated_chunks.dart';
import 'package:moonloom/domain/models/narration.dart';

/// Stand-in for the reader's size-based splitter: one chunk per call, so the
/// tests measure the hybrid rule rather than the size heuristic.
List<String> _whole(String text) => [text];

/// A splitter that always halves, to prove size chunking still runs *within* a
/// run of same-direction paragraphs.
List<String> _halve(String text) {
  if (text.length < 2) return [text];
  final mid = text.length ~/ 2;
  return [text.substring(0, mid), text.substring(mid)];
}

void main() {
  const text = 'One.\n\nTwo.\n\nThree.\n\nFour.';

  test('no direction at all behaves exactly like today', () {
    final chunks = narratedChunks(text, const NarrationNotes(), _whole);
    expect(chunks.length, 1);
    expect(chunks.single.text, text);
    expect(chunks.single.cacheSuffix, '');
  });

  test('one direction across the whole chapter costs no extra requests', () {
    const notes = NarrationNotes(
      cues: [
        NarrationCue(pace: 'slow'),
        NarrationCue(pace: 'slow'),
        NarrationCue(pace: 'slow'),
        NarrationCue(pace: 'slow'),
      ],
    );
    final chunks = narratedChunks(text, notes, _whole);
    expect(chunks.length, 1, reason: 'direction never changes');
    expect(chunks.single.cue.pace, 'slow');
  });

  test('a boundary appears where the feeling changes', () {
    const notes = NarrationNotes(
      cues: [
        NarrationCue(emotion: 'calm'),
        NarrationCue(emotion: 'calm'),
        NarrationCue(emotion: 'excited'),
        NarrationCue(emotion: 'excited'),
      ],
    );
    final chunks = narratedChunks(text, notes, _whole);
    expect(chunks.length, 2);
    expect(chunks[0].text, 'One.\n\nTwo.');
    expect(chunks[0].cue.emotion, 'calm');
    expect(chunks[1].text, 'Three.\n\nFour.');
    expect(chunks[1].cue.emotion, 'excited');
  });

  test('an undirected paragraph between two feelings is its own chunk', () {
    const notes = NarrationNotes(
      cues: [
        NarrationCue(emotion: 'calm'),
        NarrationCue(),
        NarrationCue(emotion: 'excited'),
        NarrationCue(emotion: 'excited'),
      ],
    );
    final chunks = narratedChunks(text, notes, _whole);
    expect(chunks.map((c) => c.text).toList(), [
      'One.',
      'Two.',
      'Three.\n\nFour.',
    ]);
    expect(chunks[1].cue.isEmpty, isTrue);
  });

  test('size chunking still runs inside a same-direction run', () {
    const notes = NarrationNotes(
      cues: [
        NarrationCue(emotion: 'calm'),
        NarrationCue(emotion: 'calm'),
        NarrationCue(emotion: 'excited'),
        NarrationCue(emotion: 'excited'),
      ],
    );
    final chunks = narratedChunks(text, notes, _halve);
    expect(chunks.length, 4, reason: '2 runs x 2 halves');
    expect(chunks[0].cue.emotion, 'calm');
    expect(chunks[1].cue.emotion, 'calm');
    expect(chunks[2].cue.emotion, 'excited');
  });

  test('a change of pace alone does not split the audio', () {
    // Splitting here would hand the listener two separately synthesized
    // narrators for the sake of one adverb.
    const notes = NarrationNotes(
      cues: [
        NarrationCue(pace: 'slow'),
        NarrationCue(pace: 'slow'),
        NarrationCue(pace: 'brisk'),
        NarrationCue(pace: 'brisk'),
      ],
    );
    expect(narratedChunks(text, notes, _whole).length, 1);
  });

  test('the cue rides into the cache key so a re-cue re-synthesizes', () {
    const a = NarrationNotes(cues: [NarrationCue(pace: 'slow')]);
    const b = NarrationNotes(cues: [NarrationCue(pace: 'brisk')]);
    final one = narratedChunks('Only.', a, _whole).single;
    final two = narratedChunks('Only.', b, _whole).single;
    expect(one.text, two.text);
    expect(one.cacheSuffix, isNot(two.cacheSuffix));
  });

  test('fewer cues than paragraphs leaves the tail undirected', () {
    const notes = NarrationNotes(cues: [NarrationCue(emotion: 'calm')]);
    final chunks = narratedChunks(text, notes, _whole);
    expect(chunks.first.text, 'One.');
    expect(chunks.first.cue.emotion, 'calm');
    expect(chunks.last.cue.isEmpty, isTrue);
  });

  test('empty text yields nothing to speak', () {
    expect(narratedChunks('   ', const NarrationNotes(), _whole), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:sleepytime/adapters/tts/voice_catalog.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/models/world.dart';

void main() {
  group('a world keeps its own storyteller', () {
    test('a new world has no voice, meaning the parent setting', () {
      const w = World(id: 'w1', childId: 'c1', name: 'The Lantern Wood');
      expect(w.voiceName, isEmpty);
    });

    test('the voice survives a copyWith that changes something else', () {
      const w = World(
        id: 'w1',
        childId: 'c1',
        name: 'The Lantern Wood',
        voiceName: 'Sulafat',
      );
      expect(w.copyWith(name: 'Renamed').voiceName, 'Sulafat');
      expect(w.copyWith(theme: StoryTheme.adventure).voiceName, 'Sulafat');
    });

    test('it can be cleared back to the parent setting', () {
      const w = World(
        id: 'w1',
        childId: 'c1',
        name: 'The Lantern Wood',
        voiceName: 'Sulafat',
      );
      expect(w.copyWith(voiceName: '').voiceName, isEmpty);
    });
  });

  group('the voice catalogue', () {
    test('every id is one the engine actually offers', () {
      // The friendly names are labels; the ids are what gets stored, sent and
      // keyed on. An id that drifted from the engine's own list would fail
      // only at synthesis time, for one child, on one world.
      for (final v in geminiVoices) {
        expect(
          GeminiTtsSynthesizer.voices,
          contains(v.id),
          reason: '${v.label} maps to ${v.id}',
        );
      }
    });

    test('no two voices share a friendly name', () {
      final labels = [for (final v in geminiVoices) v.label];
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('no two entries share an id', () {
      final ids = [for (final v in geminiVoices) v.id];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every voice carries the characteristic its name is based on', () {
      for (final v in geminiVoices) {
        expect(v.character, isNotEmpty, reason: v.label);
      }
    });

    test('the bedtime voices come first', () {
      // Nobody scrolls a list of thirty. The ones worth trying first have to
      // be the ones that suit being read to at bedtime.
      final firstSix = geminiVoices.take(6).map((v) => v.character).toList();
      expect(
        firstSix,
        everyElement(
          isIn(const [
            'warm',
            'gentle',
            'soft',
            'friendly',
            'easy-going',
            'breezy',
            'breathy',
            'even',
          ]),
        ),
      );
    });

    test('an uncatalogued id falls back to showing itself', () {
      // OpenAI's voices and ElevenLabs ids are not in this catalogue, and a
      // picker showing a blank chip would be worse than showing "nova".
      expect(voiceLabel('nova'), 'nova');
      expect(voiceCharacter('nova'), isEmpty);
    });

    test('a catalogued id shows its friendly name', () {
      expect(voiceLabel('Sulafat'), 'Honey');
      expect(voiceCharacter('Sulafat'), 'warm');
      expect(voiceLabel('Enceladus'), 'Whisper');
    });
  });
}

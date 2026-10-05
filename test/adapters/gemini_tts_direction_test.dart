import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:moonloom/domain/models/narration.dart';
import 'package:moonloom/domain/performance.dart';

class _FakeSecrets implements SecretStore {
  @override
  Future<String?> readKey(String providerId) async => 'test-key';
  @override
  Future<bool> hasKey(String providerId) async => true;
  @override
  Future<void> writeKey(String providerId, String key) async {}
  @override
  Future<void> deleteKey(String providerId) async {}
}

/// A minimal RIFF header and a little silence, the shape 3.8 answers with.
List<int> _wav() => [
  ...'RIFF'.codeUnits,
  36 + 8,
  0,
  0,
  0,
  ...'WAVEfmt '.codeUnits,
  16,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0xC0,
  0x5D,
  0,
  0,
  0x80,
  0xBB,
  0,
  0,
  2,
  0,
  16,
  0,
  ...'data'.codeUnits,
  8,
  0,
  0,
  0,
  ...List.filled(8, 0),
];

void main() {
  /// Captures what would have gone to Google, and from where.
  late Map<String, dynamic> sent;
  late Uri sentTo;

  http.Client client() => MockClient((request) async {
    sent = jsonDecode(request.body) as Map<String, dynamic>;
    sentTo = request.url;
    if (request.url.path.endsWith('/interactions')) {
      return http.Response(
        jsonEncode({
          'steps': [
            {
              'type': 'model_output',
              'content': [
                {'type': 'audio', 'data': base64.encode(_wav())},
              ],
            },
          ],
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inlineData': {'data': base64.encode(List.filled(64, 0))},
                },
              ],
            },
          },
        ],
      }),
      200,
    );
  });

  GeminiTtsSynthesizer synth({
    String model = GeminiTtsSynthesizer.defaultModel,
    String? heroName,
    String? heroVoice,
  }) => GeminiTtsSynthesizer(
    secrets: _FakeSecrets(),
    httpClient: client(),
    voiceName: 'Sulafat',
    model: model,
    heroName: heroName,
    heroVoice: heroVoice,
  );

  List<Map<String, dynamic>> parts() =>
      (((sent['input'] as List).first as Map)['content'] as List)
          .cast<Map<String, dynamic>>();

  String spoken() => parts().map((p) => p['text'] as String).join();

  Map<String, dynamic>? metadata(Map<String, dynamic> part) =>
      ((part['annotations'] as List?)?.first as Map?)?.cast<String, dynamic>();

  const prose =
      'Crystal knelt in the moss and cupped both hands around the glass.';
  const direction = 'Read this warmly and unhurriedly, as a bedtime story.';
  const cue = NarrationCue(pace: 'slow', volume: 'hushed', emotion: 'wistful');

  // A live transcription once caught this adapter feeding the narrator its
  // own stage directions, which came out of the speaker ahead of the story.
  // The 3.8 models gave direction a field of its own; the text must still be
  // the story's words and nothing else.
  group('3.8: direction is acted, never spoken', () {
    test('uses the interactions endpoint', () async {
      await synth().synthesize(prose);
      expect(sentTo.path, endsWith('/v1beta/interactions'));
      expect(sent['model'], GeminiTtsSynthesizer.defaultModel);
    });

    test('the text is exactly the prose', () async {
      await synth().synthesize(prose, cue: cue, standingDirection: direction);
      expect(spoken(), prose);
    });

    test('the direction goes in speech_metadata.style', () async {
      await synth().synthesize(prose, cue: cue, standingDirection: direction);
      final style = metadata(parts().single)!['style'] as String;
      expect(style, contains('warmly'));
      expect(style, contains('slow'));
      expect(style, contains('wistful'));
    });

    test('plain reading sends no empty annotation', () async {
      await synth().synthesize(prose);
      expect(parts().single.containsKey('annotations'), isFalse);
    });

    test('the narrator voice reaches the request', () async {
      await synth().synthesize(prose);
      final config =
          (sent['generation_config'] as Map)['speech_config'] as List;
      expect((config.single as Map)['voice'], 'Sulafat');
    });

    // `<…>` is a vocal tag and `|…|` an interjection in the 3.8 transcript.
    // Prose never means either, and a stray one would be performed.
    test('markup characters in the prose are never sent', () async {
      await synth().synthesize('Pip | the <brave> one');
      expect(spoken(), isNot(contains('<')));
      expect(spoken(), isNot(contains('>')));
      expect(spoken(), isNot(contains('|')));
    });

    test('the WAV it answers with is returned as it is', () async {
      final bytes = await synth().synthesize(prose);
      expect(bytes, _wav());
    });
  });

  group('3.8: the hero speaks, the narrator acts', () {
    final performance = [
      const SpeechPart('Pip swam up. ', PartVoice.narrator, 'hushed'),
      const SpeechPart('"Look!"', PartVoice.hero, 'delighted'),
      const SpeechPart(
        ' Barnaby said, "Only the moon."',
        PartVoice.narrator,
        'voicing Barnaby: gruff',
      ),
    ];
    final text = performance.map((p) => p.text).join();

    test('the parts are sent in order and are exactly the text', () async {
      await synth(
        heroName: 'Pip',
        heroVoice: 'voice_pip',
      ).synthesize(text, parts: performance);
      expect(spoken(), text);
      expect(parts(), hasLength(3));
    });

    test('with a hero voice it is a two-voice request', () async {
      await synth(
        heroName: 'Pip',
        heroVoice: 'voice_pip',
      ).synthesize(text, parts: performance);
      final config = (sent['generation_config'] as Map)['speech_config'] as Map;
      expect(config['mode'], 'conversational');
      expect(config['speakers'], [
        {'speaker': 'Narrator', 'voice': 'Sulafat'},
        {'speaker': 'Hero', 'voice': 'voice_pip'},
      ]);
      expect(parts().map((p) => metadata(p)!['speaker']), [
        'Narrator',
        'Hero',
        'Narrator',
      ]);
    });

    test("the narrator's acting direction travels with the line", () async {
      await synth(
        heroName: 'Pip',
        heroVoice: 'voice_pip',
      ).synthesize(text, parts: performance);
      expect(metadata(parts()[2])!['style'], 'voicing Barnaby: gruff');
    });

    // The child is never given a voice, so no hero voice is the common case.
    test('without a hero voice it stays a single voice', () async {
      await synth().synthesize(text, parts: performance);
      final config = (sent['generation_config'] as Map)['speech_config'];
      expect(config, isA<List>());
      expect(
        parts().every((p) => !(metadata(p)?.containsKey('speaker') ?? false)),
        isTrue,
      );
    });

    test('pure narration stays single voice even with a hero', () async {
      await synth(heroName: 'Pip', heroVoice: 'voice_pip').synthesize(
        'The moon rose.',
        parts: const [SpeechPart('The moon rose.', PartVoice.narrator, '')],
      );
      expect((sent['generation_config'] as Map)['speech_config'], isA<List>());
    });
  });

  // Every recording already made is keyed by the narrator's signature. A hero
  // voice changes whose voice a line is in, so it must change the key — but
  // only when there is one, or the library would look deleted.
  group('the signature', () {
    test('unchanged for the narrator alone', () {
      expect(
        synth().voiceSignature,
        'gemini/gemini-3.8-flash-lite-tts/Sulafat',
      );
    });

    test('includes the hero when the hero has a voice', () {
      expect(
        synth(heroName: 'Pip', heroVoice: 'voice_pip').voiceSignature,
        'gemini/gemini-3.8-flash-lite-tts/Sulafat+Pip=voice_pip',
      );
    });
  });

  // The older models still recite direction, so they get the prose alone.
  group('older models: prose only', () {
    const legacy = 'gemini-2.5-flash-preview-tts';

    test('uses generateContent and sends only the prose', () async {
      await synth(
        model: legacy,
      ).synthesize(prose, cue: cue, standingDirection: direction);
      expect(sentTo.path, endsWith('/models/$legacy:generateContent'));
      final text =
          ((((sent['contents'] as List).first as Map)['parts'] as List).first
                  as Map)['text']
              as String;
      expect(text, prose);
    });
  });
}

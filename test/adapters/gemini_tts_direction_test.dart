import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:moonloom/domain/models/narration.dart';

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

void main() {
  /// Captures what would have gone to Google.
  late Map<String, dynamic> sent;

  http.Client clientCapturing() => MockClient((request) async {
    sent = jsonDecode(request.body) as Map<String, dynamic>;
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

  String spokenText() =>
      ((((sent['contents'] as List).first as Map)['parts'] as List).first
              as Map)['text']
          as String;

  // A live transcription caught the adapter feeding the narrator its own
  // stage directions, which came out of the speaker ahead of the story:
  // "Read this warmly and unhurriedly, as a bedtime story for a child of six.
  // For this passage, slow, hushed, wistful. Crystal knelt in the moss…"
  //
  // Gemini TTS has nowhere to put direction — no style field for a prebuilt
  // voice, and system_instruction is refused — so the only safe payload is
  // the prose. These tests exist to stop that being re-added by someone
  // reading the cue fields and reasonably assuming they should be sent.
  group('nothing but the story reaches the speaker', () {
    const prose = 'Crystal knelt in the moss and cupped both hands.';

    test('a standing direction is not spoken', () async {
      final tts = GeminiTtsSynthesizer(
        secrets: _FakeSecrets(),
        httpClient: clientCapturing(),
      );
      await tts.synthesize(
        prose,
        standingDirection:
            'Read this warmly and unhurriedly, as a bedtime story. '
            'Voice the characters: Bolt, low and rumbling.',
      );
      expect(spokenText(), prose);
    });

    test('a cue is not spoken', () async {
      final tts = GeminiTtsSynthesizer(
        secrets: _FakeSecrets(),
        httpClient: clientCapturing(),
      );
      await tts.synthesize(
        prose,
        cue: const NarrationCue(
          pace: 'slow',
          emotion: 'wistful',
          volume: 'hushed',
          note: 'linger on the last line',
        ),
      );
      expect(spokenText(), prose);
      for (final word in ['slow', 'wistful', 'hushed', 'linger']) {
        expect(
          spokenText().toLowerCase(),
          isNot(contains(word)),
          reason: '"$word" would be read to a child',
        );
      }
    });

    test('both together still send only the prose', () async {
      final tts = GeminiTtsSynthesizer(
        secrets: _FakeSecrets(),
        httpClient: clientCapturing(),
      );
      await tts.synthesize(
        prose,
        standingDirection: 'Warm and unhurried.',
        cue: const NarrationCue(emotion: 'wistful'),
      );
      expect(spokenText(), prose);
    });

    test('the request carries exactly one text part', () async {
      // Two parts would be two things to read out, and the second would be
      // whatever somebody decided to put beside the story.
      final tts = GeminiTtsSynthesizer(
        secrets: _FakeSecrets(),
        httpClient: clientCapturing(),
      );
      await tts.synthesize(prose, standingDirection: 'Warm.');
      final parts = ((sent['contents'] as List).first as Map)['parts'] as List;
      expect(parts, hasLength(1));
    });

    test('the voice still reaches the request', () async {
      // The direction is gone; the voice must not go with it.
      final tts = GeminiTtsSynthesizer(
        secrets: _FakeSecrets(),
        httpClient: clientCapturing(),
        voiceName: 'Sulafat',
      );
      await tts.synthesize(prose);
      final speech = (sent['generationConfig'] as Map)['speechConfig'] as Map;
      final voice =
          ((speech['voiceConfig'] as Map)['prebuiltVoiceConfig'] as Map);
      expect(voice['voiceName'], 'Sulafat');
    });
  });
}

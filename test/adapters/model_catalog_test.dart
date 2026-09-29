import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/ai/model_catalog.dart';
import 'package:moonloom/adapters/ai/provider_exceptions.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';

/// Each vendor answers in its own shape. The bodies here are trimmed copies of
/// the real responses — the parsing has to survive the fields we don't use.
class _Keys implements SecretStore {
  _Keys({this.key = 'test-key'});
  final String? key;
  @override
  Future<String?> readKey(String providerId) async => key;
  @override
  Future<bool> hasKey(String providerId) async => key != null;
  @override
  Future<void> writeKey(String providerId, String key) async {}
  @override
  Future<void> deleteKey(String providerId) async {}
}

MockClient _json(Object body, {int status = 200}) => MockClient(
  (_) async => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  ),
);

void main() {
  group('Anthropic', () {
    test('reads display names and tiers, all text', () async {
      final models = await AnthropicModelDirectory(
        secrets: _Keys(),
        httpClient: _json({
          'data': [
            {'id': 'claude-opus-4-8', 'display_name': 'Claude Opus 4.8'},
            {'id': 'claude-haiku-4-5', 'display_name': 'Claude Haiku 4.5'},
          ],
          'has_more': false,
        }),
      ).list();

      expect(models.map((m) => m.id), ['claude-opus-4-8', 'claude-haiku-4-5']);
      expect(models.first.label, 'Claude Opus 4.8');
      expect(models.every((m) => m.kind == ModelKind.text), isTrue);
      expect(models.first.note, contains('Most capable'));
      expect(models.last.note, contains('Fastest'));
    });

    test('no key is a configuration error, not an empty list', () async {
      await expectLater(
        AnthropicModelDirectory(secrets: _Keys(key: null)).list(),
        throwsA(isA<ProviderNotConfigured>()),
      );
    });

    test('a refusal carries the provider\'s own message', () async {
      await expectLater(
        AnthropicModelDirectory(
          secrets: _Keys(),
          httpClient: _json({
            'error': {'message': 'invalid x-api-key'},
          }, status: 401),
        ).list(),
        throwsA(
          isA<ProviderRequestException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', contains('invalid')),
        ),
      );
    });
  });

  group('OpenAI', () {
    test('sorts one flat list into story, voice, and neither', () async {
      final models = await OpenAiModelDirectory(
        secrets: _Keys(),
        httpClient: _json({
          'data': [
            {'id': 'gpt-4o'},
            {'id': 'gpt-4o-mini'},
            {'id': 'gpt-4o-mini-tts'},
            {'id': 'text-embedding-3-small'},
            {'id': 'whisper-1'},
            {'id': 'dall-e-3'},
            {'id': 'omni-moderation-latest'},
          ],
        }),
      ).list();

      Iterable<String> ofKind(ModelKind k) =>
          models.where((m) => m.kind == k).map((m) => m.id);

      expect(ofKind(ModelKind.text), ['gpt-4o', 'gpt-4o-mini']);
      expect(ofKind(ModelKind.audio), ['gpt-4o-mini-tts']);
      // Embeddings, transcription, images and moderation are never offered.
      expect(ofKind(ModelKind.other), hasLength(4));
      expect(
        models.firstWhere((m) => m.id == 'gpt-4o-mini').note,
        contains('faster and cheaper'),
      );
    });
  });

  group('Google', () {
    test('reads capability from the response, TTS from the id', () async {
      final models = await GoogleModelDirectory(
        secrets: _Keys(),
        httpClient: _json({
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'displayName': 'Gemini 2.5 Flash',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-2.5-flash-preview-tts',
              'displayName': 'Gemini 2.5 Flash Preview TTS',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/text-embedding-004',
              'displayName': 'Embedding 004',
              'supportedGenerationMethods': ['embedContent'],
            },
          ],
        }),
      ).list();

      final byId = {for (final m in models) m.id: m};
      // The "models/" prefix must come off — the API wants the bare id back.
      expect(byId.keys, contains('gemini-2.5-flash'));
      expect(byId['gemini-2.5-flash']!.kind, ModelKind.text);
      // A TTS model still advertises generateContent, so the id decides.
      expect(byId['gemini-2.5-flash-preview-tts']!.kind, ModelKind.audio);
      expect(byId['gemini-2.5-flash-preview-tts']!.preview, isTrue);
      expect(byId['text-embedding-004']!.kind, ModelKind.other);
    });
  });

  test('image, music and robot models are not story models', () async {
    // Every id here came back from a live catalogue answering
    // `generateContent`. Classified on that alone, the app offered a music
    // generator as a story writer and — because "pro" is in the name —
    // called it "most capable, best prose". A mocked response would never
    // have shown this; the live probe did.
    final models = await GoogleModelDirectory(
      secrets: _Keys(),
      httpClient: _json({
        'models': [
          for (final id in [
            'gemini-2.5-flash',
            'gemini-2.5-flash-image',
            'gemini-3-pro-image',
            'nano-banana-pro-preview',
            'lyria-3-pro-preview',
            'gemini-robotics-er-2-preview',
            'gemini-2.5-computer-use-preview-10-2025',
            'deep-research-pro-preview-12-2025',
            'antigravity-preview-05-2026',
          ])
            {
              'name': 'models/$id',
              'displayName': id,
              'supportedGenerationMethods': ['generateContent'],
            },
        ],
      }),
    ).list();

    final text = models.where((m) => m.kind == ModelKind.text).map((m) => m.id);
    expect(text, ['gemini-2.5-flash']);
    expect(
      models.map((m) => m.note),
      isNot(contains('Most capable — best prose')),
      reason: 'nothing here writes prose except the one text model',
    );
  });

  group('ElevenLabs', () {
    test('takes the speech flag and trims the description', () async {
      final models = await ElevenLabsModelDirectory(
        secrets: _Keys(),
        httpClient: _json([
          {
            'model_id': 'eleven_v3',
            'name': 'Eleven v3',
            'can_do_text_to_speech': true,
            'description': 'A' * 200,
          },
          {
            'model_id': 'scribe_v1',
            'name': 'Scribe v1',
            'can_do_text_to_speech': false,
            'description': 'Transcription only.',
          },
        ]),
      ).list();

      expect(models.first.kind, ModelKind.audio);
      expect(models.first.note.length, lessThanOrEqualTo(81));
      expect(models.last.kind, ModelKind.other);
    });
  });

  test('Google lists newest first, families apart', () async {
    final models = await GoogleModelDirectory(
      secrets: _Keys(),
      httpClient: _json({
        'models': [
          for (final id in [
            'gemini-2.5-flash',
            'gemini-3.7-flash',
            'gemma-4-31b-it',
            'gemini-3.5-flash',
            'gemini-flash-latest',
            'gemini-3.1-pro-preview',
          ])
            {
              'name': 'models/$id',
              'displayName': id,
              'supportedGenerationMethods': ['generateContent'],
            },
        ],
      }),
    ).list();

    expect(models.map((m) => m.id), [
      'gemini-3.7-flash',
      'gemini-3.5-flash',
      'gemini-3.1-pro-preview',
      'gemini-2.5-flash',
      // An alias claims no version, so it sits below the numbered releases
      // rather than above them.
      'gemini-flash-latest',
      // gemma-4 is not newer than gemini-3.7; one numeric order would say so.
      'gemma-4-31b-it',
    ]);
  });

  test('OpenAI lists newest first by the timestamp it supplies', () async {
    final models = await OpenAiModelDirectory(
      secrets: _Keys(),
      httpClient: _json({
        'data': [
          {'id': 'gpt-4o', 'created': 1000},
          {'id': 'gpt-5', 'created': 3000},
          {'id': 'gpt-4o-mini', 'created': 2000},
        ],
      }),
    ).list();

    expect(models.map((m) => m.id), ['gpt-5', 'gpt-4o-mini', 'gpt-4o']);
  });

  test('preview ids are flagged wherever they come from', () {
    expect(isPreviewId('gemini-2.5-flash-preview-tts'), isTrue);
    expect(isPreviewId('gemini-2.0-flash-exp'), isTrue);
    expect(isPreviewId('gpt-4o'), isFalse);
    expect(isPreviewId('claude-opus-4-8'), isFalse);
  });
}

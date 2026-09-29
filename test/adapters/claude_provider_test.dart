import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/ai/ai_provider.dart';
import 'package:moonloom/adapters/ai/claude_provider.dart';
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/ai/openai_provider.dart';
import 'package:moonloom/adapters/ai/provider_exceptions.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/prompt_builder.dart';

class _FakeSecrets implements SecretStore {
  _FakeSecrets(this.key);
  String? key;
  @override
  Future<bool> hasKey(String p) async => key != null && key!.isNotEmpty;
  @override
  Future<String?> readKey(String p) async => key;
  @override
  Future<void> writeKey(String p, String k) async => key = k;
  @override
  Future<void> deleteKey(String p) async => key = null;
}

http.Response _ok(Map<String, dynamic> segment) => http.Response(
  jsonEncode({
    'stop_reason': 'end_turn',
    'content': [
      {'type': 'text', 'text': jsonEncode(segment)},
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  const segment = {
    'story_text': 'Once upon a calm night, Aiden drifted gently to sleep.',
    'summary': 'Aiden drifted to sleep.',
    'rating': 'tiny',
    'setting': 'a cozy room',
    'sensitive_flags': <String>[],
    'characters': ['Aiden'],
    'open_threads': <String>[],
  };
  const prompt = StoryPrompt(system: 'sys', user: 'usr');

  test('sends the right request shape and parses the segment', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-4-8');
      expect(req.headers['x-api-key'], 'sk-test');
      expect(req.headers['anthropic-version'], '2023-06-01');
      expect((body['output_config'] as Map)['format'], isNotNull);
      return _ok(segment);
    });
    final provider = ClaudeProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );

    expect(provider.id, ProviderId.claude);
    final seg = await provider.generate(prompt);
    expect(seg.storyText, contains('Aiden'));
    expect(seg.rating, AgeRating.tiny);
    expect(seg.characters, contains('Aiden'));
  });

  test('throws ProviderNotConfigured when no key is set', () async {
    final provider = ClaudeProvider(
      secrets: _FakeSecrets(null),
      httpClient: MockClient((_) async => _ok(segment)),
    );
    expect(await provider.isReady(), isFalse);
    expect(provider.generate(prompt), throwsA(isA<ProviderNotConfigured>()));
  });

  test('throws ProviderRefusal on a refusal stop reason', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'stop_reason': 'refusal', 'content': <dynamic>[]}),
        200,
      ),
    );
    final provider = ClaudeProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );
    expect(provider.generate(prompt), throwsA(isA<ProviderRefusal>()));
  });

  test('throws ProviderRequestException on a non-200 response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'invalid key'},
        }),
        401,
      ),
    );
    final provider = ClaudeProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );
    expect(provider.generate(prompt), throwsA(isA<ProviderRequestException>()));
  });

  test(
    'OpenAiProvider parses a chat-completions structured response',
    () async {
      final client = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer sk-test');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect((body['response_format'] as Map)['type'], 'json_schema');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(segment), 'refusal': null},
              },
            ],
          }),
          200,
        );
      });
      final provider = OpenAiProvider(
        secrets: _FakeSecrets('sk-test'),
        httpClient: client,
      );
      expect(provider.id, ProviderId.openai);
      final seg = await provider.generate(prompt);
      expect(seg.storyText, contains('Aiden'));
      expect(seg.rating, AgeRating.tiny);
    },
  );

  test('GeminiProvider parses a generateContent structured response', () async {
    final client = MockClient((req) async {
      expect(req.headers['x-goog-api-key'], 'sk-test');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final genConfig = body['generationConfig'] as Map;
      expect(genConfig['responseMimeType'], 'application/json');
      // Thinking must be OFF so it can't eat the output-token budget and
      // truncate the JSON.
      expect((genConfig['thinkingConfig'] as Map)['thinkingBudget'], 0);
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {'text': jsonEncode(segment)},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final provider = GeminiProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );
    expect(provider.id, ProviderId.gemini);
    final seg = await provider.generate(prompt);
    expect(seg.characters, contains('Aiden'));
  });

  test('GeminiProvider surfaces a MAX_TOKENS truncation as an error', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'candidates': [
            {'finishReason': 'MAX_TOKENS'},
          ],
        }),
        200,
      ),
    );
    final provider = GeminiProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );
    expect(provider.generate(prompt), throwsA(isA<ProviderRequestException>()));
  });

  test('GeminiProvider treats a SAFETY finish as a refusal', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'candidates': [
            {'finishReason': 'SAFETY'},
          ],
        }),
        200,
      ),
    );
    final provider = GeminiProvider(
      secrets: _FakeSecrets('sk-test'),
      httpClient: client,
    );
    expect(provider.generate(prompt), throwsA(isA<ProviderRefusal>()));
  });
}

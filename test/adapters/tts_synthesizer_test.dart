import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/ai/provider_exceptions.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/elevenlabs_tts_synthesizer.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:moonloom/adapters/tts/openai_tts_synthesizer.dart';
import 'package:moonloom/adapters/tts/tts_synthesizer.dart';

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

void main() {
  final audio = Uint8List.fromList([0xFF, 0xF3, 0x10, 0x20]); // pretend mp3

  group('pcmToWav', () {
    test('prepends a RIFF/WAVE header sized to the PCM', () {
      final pcm = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final wav = pcmToWav(pcm, sampleRate: 24000);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, 44 + pcm.length);
      expect(wav.sublist(44), pcm);
    });
  });

  group('OpenAiTtsSynthesizer', () {
    test('posts to /audio/speech and returns the audio bytes', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/v1/audio/speech');
        expect(req.headers['authorization'], 'Bearer sk-test');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['voice'], 'nova');
        expect(body['response_format'], 'mp3');
        return http.Response.bytes(audio, 200);
      });
      final s = OpenAiTtsSynthesizer(
        secrets: _FakeSecrets('sk-test'),
        httpClient: client,
      );
      expect(s.mimeType, 'audio/mpeg');
      expect(await s.synthesize('hello'), audio);
    });

    test('throws when no key is set', () async {
      final s = OpenAiTtsSynthesizer(
        secrets: _FakeSecrets(null),
        httpClient: MockClient((_) async => http.Response.bytes(audio, 200)),
      );
      expect(s.synthesize('hi'), throwsA(isA<ProviderNotConfigured>()));
    });
  });

  group('ElevenLabsTtsSynthesizer', () {
    test('posts to the voice endpoint with xi-api-key', () async {
      final client = MockClient((req) async {
        expect(req.url.path, contains('/v1/text-to-speech/'));
        expect(req.headers['xi-api-key'], 'sk-test');
        return http.Response.bytes(audio, 200);
      });
      final s = ElevenLabsTtsSynthesizer(
        secrets: _FakeSecrets('sk-test'),
        httpClient: client,
      );
      expect(await s.synthesize('hello'), audio);
    });
  });

  group('GeminiTtsSynthesizer', () {
    test('wraps the returned PCM in a WAV container', () async {
      final pcm = Uint8List.fromList([9, 8, 7, 6]);
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect((body['generationConfig'] as Map)['responseModalities'], [
          'AUDIO',
        ]);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {
                        'mimeType': 'audio/L16;rate=24000',
                        'data': base64.encode(pcm),
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final s = GeminiTtsSynthesizer(
        secrets: _FakeSecrets('sk-test'),
        httpClient: client,
      );
      expect(s.mimeType, 'audio/wav');
      final wav = await s.synthesize('hello');
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(wav.sublist(44), pcm);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/ai/provider_exceptions.dart';
import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/gemini_voice_designer.dart';

class _Key implements SecretStore {
  @override
  Future<String?> readKey(String id) async => 'k';
  @override
  Future<bool> hasKey(String id) async => true;
  @override
  Future<void> writeKey(String id, String key) async {}
  @override
  Future<void> deleteKey(String id) async {}
}

/// A plain WAV with a C2PA chunk after it, as every Gemini reply carries.
Uint8List _sampleWithManifest() {
  final plain = encodeWav(
    WavAudio(
      samples: Int16List.fromList(List.generate(480, (i) => i * 10)),
      sampleRate: 24000,
      channels: 1,
    ),
  );
  final b = BytesBuilder()
    ..add(plain)
    ..add('C2PA'.codeUnits)
    ..add(Uint8List(4)..buffer.asByteData().setUint32(0, 64, Endian.little))
    ..add(Uint8List(64));
  final out = b.toBytes();
  out.buffer.asByteData().setUint32(4, out.length - 8, Endian.little);
  return out;
}

void main() {
  late Map<String, dynamic>? sent;
  late Uri sentTo;

  GeminiVoiceDesigner designer(http.Response Function(http.Request) reply) =>
      GeminiVoiceDesigner(
        secrets: _Key(),
        httpClient: MockClient((r) async {
          sentTo = r.url;
          sent = r.body.isEmpty
              ? null
              : jsonDecode(r.body) as Map<String, dynamic>;
          return reply(r);
        }),
      );

  group('designing a voice', () {
    test('saves a prompted voice under the app\'s own name', () async {
      await designer(
        (_) => http.Response(
          jsonEncode({'name': 'voices/voice_abc', 'display_name': 'x'}),
          200,
        ),
      ).design(name: 'Pip', prompt: 'a bright tenor');
      expect(sentTo.path, endsWith('/v1beta/voices'));
      expect(sent!['store'], isTrue);
      final voice = sent!['voice'] as Map;
      expect(voice['type'], 'prompted');
      expect(voice['display_name'], 'Moonloom Pip');
      expect((voice['prompted'] as Map)['input'], 'a bright tenor');
      expect(voice['model'], GeminiVoiceDesigner.designModel);
    });

    test('returns the voice id, without its resource path', () async {
      final v = await designer(
        (_) => http.Response(
          jsonEncode({
            'name': 'voices/voice_abc',
            'display_name': 'Moonloom Pip',
          }),
          200,
        ),
      ).design(name: 'Pip', prompt: 'p');
      expect(v.id, 'voice_abc');
      expect(v.name, 'Pip');
    });

    // Every Gemini WAV carries a C2PA manifest after its sound, which played
    // as static when read naively. The preview is a Gemini WAV like any other.
    test('the preview is the sound only, with no manifest', () async {
      final v = await designer(
        (_) => http.Response(
          jsonEncode({
            'name': 'voice_abc',
            'display_name': 'Moonloom Pip',
            'sample_audio': {'data': base64.encode(_sampleWithManifest())},
          }),
          200,
        ),
      ).design(name: 'Pip', prompt: 'p');
      expect(String.fromCharCodes(v.preview!).contains('C2PA'), isFalse);
      expect(decodeWav(v.preview!).samples, hasLength(480));
    });

    test('a safety refusal says what to change', () async {
      expect(
        designer(
          (_) => http.Response(
            jsonEncode({
              'error': {
                'code': 400,
                'message': 'Voice prompt was blocked by safety policies.',
              },
            }),
            400,
          ),
        ).design(name: 'Pip', prompt: 'a little child'),
        throwsA(
          isA<ProviderRequestException>().having(
            (e) => e.toString(),
            'message',
            contains('grown-up performer'),
          ),
        ),
      );
    });
  });

  test('lists only the voices this app designed', () async {
    final list = await designer(
      (_) => http.Response(
        jsonEncode({
          'voices': [
            {'name': 'voice_1', 'display_name': 'Moonloom Narrator'},
            {'name': 'voice_2', 'display_name': 'Someone else\'s voice'},
            {'name': 'voice_3', 'display_name': 'Moonloom Pip'},
          ],
        }),
        200,
      ),
    ).list();
    expect(list.map((v) => v.name), ['Narrator', 'Pip']);
    expect(list.map((v) => v.id), ['voice_1', 'voice_3']);
  });

  // The voice service refuses a child's voice, and the app should not want
  // one: a character is always described as an adult performing them.
  group('a character\'s voice description', () {
    final prompt = GeminiVoiceDesigner.characterPrompt('Pip', 'an axolotl');

    test('is an adult performing the character', () {
      expect(prompt, contains('adult voice actor'));
      expect(prompt, contains('Pip, an axolotl'));
    });

    test('never asks for a child', () {
      expect(prompt.toLowerCase(), isNot(contains('child voice')));
      expect(prompt.toLowerCase(), isNot(contains('young voice')));
    });
  });

  test('designed ids are told apart from prebuilt names', () {
    expect(isDesignedVoice('voice_abc'), isTrue);
    expect(isDesignedVoice('Sulafat'), isFalse);
  });
}

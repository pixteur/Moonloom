import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/elevenlabs_tts_synthesizer.dart';
import 'package:moonloom/domain/models/narration.dart';

class _FakeSecrets implements SecretStore {
  @override
  Future<String?> readKey(String providerId) async => 'test-key';
  @override
  Future<void> writeKey(String providerId, String key) async {}
  @override
  Future<bool> hasKey(String providerId) async => true;
  @override
  Future<void> deleteKey(String providerId) async {}
}

void main() {
  // Captures each request body so the text actually sent can be asserted on.
  late List<Map<String, dynamic>> sent;

  http.Client client() => MockClient((req) async {
    sent.add(jsonDecode(req.body) as Map<String, dynamic>);
    return http.Response.bytes([1, 2, 3], 200);
  });

  setUp(() => sent = <Map<String, dynamic>>[]);

  Future<void> speak(NarrationCue cue, {String? model}) async {
    final synth = ElevenLabsTtsSynthesizer(
      secrets: _FakeSecrets(),
      httpClient: client(),
      model: model ?? 'eleven_v3',
    );
    await synth.synthesize('Once upon a time.', cue: cue);
  }

  test('a hushed cue becomes a whisper tag on v3', () async {
    await speak(const NarrationCue(volume: 'hushed'));
    expect(sent.single['text'], '[whispers] Once upon a time.');
    expect(sent.single['model_id'], 'eleven_v3');
  });

  test('an excited cue becomes an excited tag', () async {
    await speak(const NarrationCue(emotion: 'excited'));
    expect(sent.single['text'], '[excited] Once upon a time.');
  });

  test('an unknown feeling is dropped, never spoken', () async {
    // The whole point of the whitelist: a tag v3 does not know is read out.
    await speak(const NarrationCue(emotion: 'flabbergasted'));
    expect(sent.single['text'], 'Once upon a time.');
  });

  test('no cue leaves the text untouched', () async {
    await speak(const NarrationCue());
    expect(sent.single['text'], 'Once upon a time.');
    expect(sent.single.containsKey('voice_settings'), isFalse);
  });

  test('an older model never receives a tag', () async {
    // v2 would speak the brackets aloud.
    await speak(
      const NarrationCue(volume: 'hushed'),
      model: 'eleven_multilingual_v2',
    );
    expect(sent.single['text'], 'Once upon a time.');
  });

  test('only one tag is added, at the front', () async {
    await speak(const NarrationCue(volume: 'hushed', emotion: 'excited'));
    final text = sent.single['text'] as String;
    expect(text.startsWith('[whispers] '), isTrue);
    expect('['.allMatches(text).length, 1);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/audio_cache.dart';

void main() {
  group('audioCacheKey', () {
    test('is deterministic for the same input', () {
      expect(
        audioCacheKey('gemini/Aoede|en|Hello'),
        audioCacheKey('gemini/Aoede|en|Hello'),
      );
    });

    test('differs by voice, language, and text', () {
      final base = audioCacheKey('gemini/Aoede|en|Hello');
      expect(base, isNot(audioCacheKey('gemini/Kore|en|Hello'))); // voice
      expect(base, isNot(audioCacheKey('gemini/Aoede|fr|Hello'))); // language
      expect(base, isNot(audioCacheKey('gemini/Aoede|en|Goodbye'))); // text
    });

    test('is a fixed-width hex string', () {
      final key = audioCacheKey('anything');
      expect(key, hasLength(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(key), isTrue);
    });
  });
}

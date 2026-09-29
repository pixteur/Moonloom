import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/ai/ai_provider.dart';
import 'package:moonloom/adapters/ai/fake_ai_provider.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/prompt_builder.dart';

void main() {
  test(
    'FakeAiProvider is ready and returns a safe, non-empty segment',
    () async {
      const provider = FakeAiProvider();
      expect(provider.id, ProviderId.fake);
      expect(await provider.isReady(), isTrue);

      const prompt = StoryPrompt(system: 'system', user: 'user');
      final segment = await provider.generate(prompt);
      expect(segment.storyText, isNotEmpty);
      expect(segment.summary, isNotEmpty);
      expect(segment.rating, AgeRating.tiny);
    },
  );

  group('AgeBand', () {
    test('maps ages to the right bands', () {
      expect(AgeBand.forAge(3), AgeBand.tiny);
      expect(AgeBand.forAge(6), AgeBand.little);
      expect(AgeBand.forAge(9), AgeBand.big);
      expect(AgeBand.forAge(12), AgeBand.older);
    });
  });
}

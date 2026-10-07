import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/app_providers.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';

import '../support/in_memory_storage_repo.dart';

/// The voice settings, fixed, so a test does not wait on preferences.
class _Fixed extends VoiceConfigController {
  _Fixed(this.config);
  final VoiceConfig config;
  @override
  VoiceConfig build() => config;
}

/// Who reads a world's stories, and who speaks in a voice of their own.
void main() {
  const mia = ChildProfile(id: 'c1', displayName: 'Mia', age: 5);

  Future<VoiceConfig> resolve({
    String worldVoice = '',
    List<StoryCharacter> cast = const [],
    VoiceConfig settings = const VoiceConfig(VoiceEngine.gemini, 'Sulafat'),
  }) async {
    final repo = InMemoryStorageRepo();
    final world = World(
      id: 'w1',
      childId: 'c1',
      name: "Pip's Adventures",
      voiceName: worldVoice,
    );
    await repo.saveWorld(world);
    for (final c in cast) {
      await repo.saveCharacter(c);
    }
    final container = ProviderContainer(
      overrides: [
        storageRepoProvider.overrideWithValue(repo),
        voiceConfigProvider.overrideWith(() => _Fixed(settings)),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeChildProvider.notifier).select(mia);
    container.read(activeWorldProvider.notifier).select(world);
    await container.read(charactersForWorldProvider('w1').future);
    return container.read(storyVoiceProvider);
  }

  const pipWithVoice = StoryCharacter(
    id: 'p',
    worldId: 'w1',
    name: 'Pip',
    voiceId: 'voice_pip',
  );

  test('a designed storyteller is honoured, not quietly ignored', () async {
    // The first version only accepted names on the prebuilt list, so a
    // designed voice id was dropped without a word.
    final cfg = await resolve(worldVoice: 'voice_story');
    expect(cfg.voiceName, 'voice_story');
  });

  test('the voiced character speaks in their own voice', () async {
    final cfg = await resolve(cast: const [pipWithVoice]);
    expect(cfg.heroName, 'Pip');
    expect(cfg.heroVoice, 'voice_pip');
  });

  test('nobody with a voice means the storyteller plays everyone', () async {
    final cfg = await resolve(
      cast: const [StoryCharacter(id: 'p', worldId: 'w1', name: 'Pip')],
    );
    expect(cfg.heroName, isNull);
    expect(cfg.heroVoice, isNull);
  });

  // The child is never given a voice, even if a row somehow carries one.
  test("the child's own name is never voiced", () async {
    final cfg = await resolve(
      cast: const [
        StoryCharacter(id: 'm', worldId: 'w1', name: 'Mia', voiceId: 'voice_x'),
      ],
    );
    expect(cfg.heroName, isNull);
  });

  // Designed voices and a second speaker exist only on the 3.8 models.
  test('an older model falls back to the plain narrator', () async {
    final cfg = await resolve(
      worldVoice: 'voice_story',
      cast: const [pipWithVoice],
      settings: const VoiceConfig(
        VoiceEngine.gemini,
        'Sulafat',
        'gemini-2.5-flash-preview-tts',
      ),
    );
    expect(cfg.voiceName, 'Sulafat');
    expect(cfg.heroVoice, isNull);
  });

  test('other engines are untouched', () async {
    final cfg = await resolve(
      worldVoice: 'voice_story',
      cast: const [pipWithVoice],
      settings: const VoiceConfig(VoiceEngine.elevenlabs, 'abc'),
    );
    expect(cfg.voiceName, 'abc');
    expect(cfg.heroVoice, isNull);
  });

  // The reader is rebuilt — and a story stopped mid-sentence — whenever this
  // changes, so the same settings must compare equal.
  test('the same voice settings are equal', () {
    expect(
      const VoiceConfig(VoiceEngine.gemini, 'a', '', 'Pip', 'v'),
      const VoiceConfig(VoiceEngine.gemini, 'a', '', 'Pip', 'v'),
    );
    expect(
      const VoiceConfig(VoiceEngine.gemini, 'a', '', 'Pip', 'v'),
      isNot(const VoiceConfig(VoiceEngine.gemini, 'a', '', 'Pip', 'w')),
    );
  });
}

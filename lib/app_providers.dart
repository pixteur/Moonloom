import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/claude_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'adapters/ai/gemini_provider.dart';
import 'adapters/ai/model_catalog.dart';
import 'adapters/ai/openai_provider.dart';
import 'adapters/prefs/app_prefs.dart';
import 'adapters/secrets/dpapi_secret_store.dart';
import 'adapters/secrets/secret_store.dart';
import 'adapters/storage/app_database.dart';
import 'adapters/storage/drift_storage_repo.dart';
import 'adapters/storage/library_paths.dart';
import 'adapters/storage/storage_repo.dart';
import 'adapters/images/picture_store.dart';
import 'adapters/images/story_illustrator.dart';
import 'adapters/tts/audio_cache.dart';
import 'adapters/tts/cloud_tts_provider.dart';
import 'adapters/tts/device_tts_provider.dart';
import 'adapters/tts/elevenlabs_tts_synthesizer.dart';
import 'adapters/tts/gemini_tts_synthesizer.dart';
import 'adapters/tts/openai_tts_synthesizer.dart';
import 'adapters/tts/tts_provider.dart';
import 'domain/character_service.dart';
import 'domain/models/beat.dart';
import 'domain/models/child_profile.dart';
import 'domain/illustration_service.dart';
import 'domain/models/series.dart';
import 'domain/models/story_image.dart';
import 'domain/models/story_character.dart';
import 'domain/models/world.dart';
import 'domain/profile_service.dart';
import 'domain/quiz_service.dart';
import 'domain/saved_narration.dart';
import 'domain/series_service.dart';
import 'domain/sleepy_service.dart';
import 'domain/story_engine.dart';
import 'domain/twist_deck.dart';
import 'domain/world_service.dart';

// ─── AI / story ───────────────────────────────────────────────────────

/// OS-secure storage for API keys (Windows DPAPI).
final secretStoreProvider = Provider<SecretStore>((ref) => DpapiSecretStore());

/// Map a stored provider name to its id (defaults to Claude).
ProviderId providerIdFromName(String name) => switch (name) {
  'openai' => ProviderId.openai,
  'gemini' => ProviderId.gemini,
  _ => ProviderId.claude,
};

/// The SecretStore key name for a real provider, or null for fake/hosted.
String? keyNameFor(ProviderId id) => switch (id) {
  ProviderId.claude => ClaudeProvider.keyName,
  ProviderId.openai => OpenAiProvider.keyName,
  ProviderId.gemini => GeminiProvider.keyName,
  ProviderId.hosted || ProviderId.fake => null,
};

/// Which AI backend is active. Defaults to [ProviderId.fake] (offline, no key)
/// and upgrades to the parent-selected provider only when its key is stored AND
/// third-party-AI consent is given (per CLAUDE.md). Settings calls
/// [AiConfigController.refresh] after changes.
final aiConfigProvider = NotifierProvider<AiConfigController, ProviderId>(
  AiConfigController.new,
);

class AiConfigController extends Notifier<ProviderId> {
  /// Completes once the grown-up's real choice has been read from settings.
  ///
  /// [build] has to answer synchronously, so it answers `fake` and loads the
  /// real choice behind it. Anything that reads the engine in that window gets
  /// the fake provider, and the fake provider does not fail — it returns
  /// canned chapters, successfully. So nothing warns, nothing is named, and a
  /// story arrives as six identical chapters reading "The gentle path home and
  /// a peaceful goodnight." The chapter screen captures the engine once and
  /// keeps it for the whole story, so one early read was enough to fake all
  /// six. Await this before taking the engine — [readyStoryEngine] does.
  Future<void> ready = Future.value();

  @override
  ProviderId build() {
    ready = _hydrate();
    return ProviderId.fake;
  }

  Future<void> _hydrate() async => state = await _resolve();

  /// Why the last resolution came out as it did, in words a grown-up can act
  /// on. Shown whenever a story is about to be written by the placeholder, so
  /// that never again happens silently — it took four sessions to diagnose
  /// "Naming it…" stories because the fake provider succeeds without a word.
  String why = 'settings have not loaded yet';

  Future<ProviderId> _resolve() async {
    final prefs = await AppPrefs.open();
    if (!prefs.aiConsentGiven) {
      why = 'permission to use a story AI has not been given';
      return ProviderId.fake;
    }
    final selected = providerIdFromName(prefs.selectedProvider);
    final keyName = keyNameFor(selected);
    if (keyName == null) {
      why = 'the chosen story AI (${selected.name}) is not available yet';
      return ProviderId.fake;
    }
    final hasKey = await ref.read(secretStoreProvider).hasKey(keyName);
    if (!hasKey) {
      why = 'no key is saved for ${selected.name}';
      return ProviderId.fake;
    }
    why = 'using ${selected.name}';
    return selected;
  }

  Future<void> refresh() async => state = await _resolve();
}

/// The story model chosen for the active provider — blank means "whatever the
/// adapter ships with". Kept apart from [aiConfigProvider] so switching
/// provider doesn't drag a Claude model id over to Gemini: the pref is keyed by
/// provider, and this re-reads it whenever the provider changes.
final textModelProvider = NotifierProvider<TextModelController, String>(
  TextModelController.new,
);

class TextModelController extends Notifier<String> {
  @override
  String build() {
    // Watch, not read: picking a different provider must re-resolve the model.
    ref.watch(aiConfigProvider);
    _hydrate();
    return '';
  }

  Future<void> _hydrate() async => state = await _resolve();

  Future<String> _resolve() async {
    final prefs = await AppPrefs.open();
    return prefs.textModel(prefs.selectedProvider) ?? '';
  }

  Future<void> refresh() async => state = await _resolve();
}

/// The active AI provider — the configured + consented one, else the offline
/// [FakeAiProvider]. See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) {
  final secrets = ref.watch(secretStoreProvider);
  final chosen = ref.watch(textModelProvider);
  return switch (ref.watch(aiConfigProvider)) {
    ProviderId.claude => ClaudeProvider(
      secrets: secrets,
      model: chosen.isEmpty ? ClaudeProvider.defaultModel : chosen,
    ),
    ProviderId.openai => OpenAiProvider(
      secrets: secrets,
      model: chosen.isEmpty ? OpenAiProvider.defaultModel : chosen,
    ),
    ProviderId.gemini => GeminiProvider(
      secrets: secrets,
      model: chosen.isEmpty ? GeminiProvider.defaultModel : chosen,
    ),
    ProviderId.hosted || ProviderId.fake => const FakeAiProvider(),
  };
});

/// The story engine, once the provider the grown-up chose has actually loaded.
///
/// Use this, not `ref.read(storyEngineProvider)`, anywhere a story is about to
/// be written. Reading the engine directly can land before settings load and
/// hand back an engine on the fake provider, which writes canned chapters
/// without any error — see [AiConfigController.ready].
Future<StoryEngine> readyStoryEngine(WidgetRef ref) async {
  // Reading the notifier builds the provider if nothing has yet, which starts
  // the load; awaiting [ready] waits for it to finish.
  await ref.read(aiConfigProvider.notifier).ready;
  await noteAiChoice(
    'story',
    config: ref.read(aiConfigProvider),
    provider: ref.read(aiProvider),
    why: ref.read(aiConfigProvider.notifier).why,
  );
  return ref.read(storyEngineProvider);
}

/// Write down which story AI the app settled on, and why, to a local file.
///
/// Settings only — the provider, the reason, the consent flag, the chosen
/// provider's name and the folder the settings came from. Never a prompt, a
/// story or anything about a child; this stays on the machine and is read by a
/// person diagnosing it.
///
/// It exists because "Naming it…" stories with placeholder chapters came from
/// the release build launched by its shortcut, while the same code run by
/// every test — debug, AOT, the real main(), the real settings, the exact
/// choices — wrote real stories. The only process that could say what it
/// decided was the one that got it wrong, so now it says.
Future<void> noteAiChoice(
  String where, {
  required ProviderId config,
  required Object provider,
  required String why,
}) async {
  try {
    final support = await getApplicationSupportDirectory();
    final prefs = await AppPrefs.open();
    final line = [
      DateTime.now().toIso8601String(),
      where.padRight(8),
      'config=$config',
      'provider=${provider.runtimeType}',
      'why="$why"',
      'consent=${prefs.aiConsentGiven}',
      'selected=${prefs.selectedProvider}',
      'settings=${support.path}',
    ].join('  ');
    await File(
      p.join(support.path, 'ai-choice.log'),
    ).writeAsString('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // A diagnostic must never be the thing that stops a story.
  }
}

/// Why the next story would be written by the offline placeholder, or null
/// when a real story AI will write it.
///
/// The placeholder never fails — it answers instantly with canned chapters —
/// so without this a misconfigured app looks exactly like a working one that
/// writes dull stories. Ask this after [readyStoryEngine] and say it out loud.
String? placeholderReason(WidgetRef ref) =>
    ref.read(aiProvider) is FakeAiProvider
    ? ref.read(aiConfigProvider.notifier).why
    : null;

/// The story engine, wired to the active provider + storage.
final storyEngineProvider = Provider<StoryEngine>(
  (ref) => StoryEngine(
    ai: ref.watch(aiProvider),
    repo: ref.watch(storageRepoProvider),
  ),
);

/// The twist deck (six option cards + dice).
final twistDeckProvider = Provider<TwistDeck>((ref) => const TwistDeck());

/// Parent mode: when true, grown-up controls (delete/rename) are shown. Default
/// false ("child mode"). Toggled in Settings (behind the parental gate).
final parentModeProvider = NotifierProvider<ParentModeController, bool>(
  ParentModeController.new,
);

class ParentModeController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async => state = (await AppPrefs.open()).parentMode;

  Future<void> set(bool value) async {
    state = value;
    await (await AppPrefs.open()).setParentMode(value);
  }
}

/// Listening mode: the reader hides its text and darkens the screen so a story
/// can be heard with eyes closed. Remembered between sessions.
final listeningModeProvider = NotifierProvider<ListeningModeController, bool>(
  ListeningModeController.new,
);

class ListeningModeController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async =>
      state = (await AppPrefs.open()).listeningMode;

  Future<void> toggle() async {
    state = !state;
    await (await AppPrefs.open()).setListeningMode(state);
  }
}

/// The vendors whose catalogues can be listed. One per API key, not one per
/// role — OpenAI's and Google's lists cover both story and voice models.
enum ModelVendor { anthropic, openai, google, elevenlabs }

/// Looks up what a vendor's key can actually reach, so the settings screens
/// offer real model ids instead of a hard-coded guess. See `model_catalog.dart`.
final modelDirectoryProvider = Provider.family<ModelDirectory, ModelVendor>((
  ref,
  vendor,
) {
  final secrets = ref.watch(secretStoreProvider);
  return switch (vendor) {
    ModelVendor.anthropic => AnthropicModelDirectory(secrets: secrets),
    ModelVendor.openai => OpenAiModelDirectory(secrets: secrets),
    ModelVendor.google => GoogleModelDirectory(secrets: secrets),
    ModelVendor.elevenlabs => ElevenLabsModelDirectory(secrets: secrets),
  };
});

/// Which vendor serves a story provider.
ModelVendor vendorForProvider(ProviderId id) => switch (id) {
  ProviderId.openai => ModelVendor.openai,
  ProviderId.gemini => ModelVendor.google,
  _ => ModelVendor.anthropic,
};

/// Which vendor serves a voice engine (null for the offline device voice).
ModelVendor? vendorForVoice(VoiceEngine engine) => switch (engine) {
  VoiceEngine.openai => ModelVendor.openai,
  VoiceEngine.gemini => ModelVendor.google,
  VoiceEngine.elevenlabs => ModelVendor.elevenlabs,
  VoiceEngine.device => null,
};

// ─── Voice engine ─────────────────────────────────────────────────────

enum VoiceEngine { device, openai, elevenlabs, gemini }

VoiceEngine voiceEngineFromName(String name) => switch (name) {
  'openai' => VoiceEngine.openai,
  'elevenlabs' => VoiceEngine.elevenlabs,
  'gemini' => VoiceEngine.gemini,
  _ => VoiceEngine.device,
};

/// The SecretStore key name a cloud voice engine uses (null for device).
String? ttsKeyNameFor(VoiceEngine engine) => switch (engine) {
  VoiceEngine.openai => OpenAiTtsSynthesizer.keyName,
  VoiceEngine.elevenlabs => ElevenLabsTtsSynthesizer.keyName,
  VoiceEngine.gemini => GeminiTtsSynthesizer.keyName,
  VoiceEngine.device => null,
};

class VoiceConfig {
  const VoiceConfig(this.engine, this.voiceName, [this.model = '']);
  final VoiceEngine engine;
  final String voiceName; // '' = engine default
  final String model; // '' = the adapter's own default
}

/// Resolves the active voice engine. Falls back to device TTS unless the chosen
/// cloud engine has a key AND third-party-AI consent is given. Settings calls
/// [VoiceConfigController.refresh] after changes.
final voiceConfigProvider =
    NotifierProvider<VoiceConfigController, VoiceConfig>(
      VoiceConfigController.new,
    );

class VoiceConfigController extends Notifier<VoiceConfig> {
  @override
  VoiceConfig build() {
    _hydrate();
    return const VoiceConfig(VoiceEngine.device, '');
  }

  Future<void> _hydrate() async => state = await _resolve();

  Future<VoiceConfig> _resolve() async {
    final prefs = await AppPrefs.open();
    final engine = voiceEngineFromName(prefs.voiceEngine);
    if (engine == VoiceEngine.device) {
      return const VoiceConfig(VoiceEngine.device, '');
    }
    if (!prefs.aiConsentGiven) return const VoiceConfig(VoiceEngine.device, '');
    final hasKey = await ref
        .read(secretStoreProvider)
        .hasKey(ttsKeyNameFor(engine)!);
    if (!hasKey) return const VoiceConfig(VoiceEngine.device, '');
    return VoiceConfig(
      engine,
      prefs.voiceName(engine.name) ?? '',
      prefs.voiceModel(engine.name) ?? '',
    );
  }

  Future<void> refresh() async => state = await _resolve();
}

/// Every voice signature that might hold a recording on this device.
///
/// The remembered list only starts filling from the build that added it, so it
/// is unioned with what the stored settings imply: for each engine, the voice
/// currently selected paired with both the chosen model and the adapter's
/// default. That covers the case this exists for — a grown-up changed voice or
/// model, and 600 MB of narration stopped being asked for.
final knownVoicesProvider = FutureProvider<List<String>>((ref) async {
  // Rebuild whenever the voice changes, so a newly used voice is included.
  ref.watch(voiceConfigProvider);
  final prefs = await AppPrefs.open();
  final out = <String>{...prefs.knownVoiceSignatures};

  void consider(
    String engine,
    String? model,
    String defaultModel,
    String voice,
  ) {
    final chosen = (model == null || model.isEmpty) ? defaultModel : model;
    out.add('$engine/$chosen/$voice');
    out.add('$engine/$defaultModel/$voice');
  }

  consider(
    'gemini',
    prefs.voiceModel('gemini'),
    GeminiTtsSynthesizer.defaultModel,
    prefs.voiceName('gemini') ?? 'Kore',
  );
  consider(
    'openai',
    prefs.voiceModel('openai'),
    OpenAiTtsSynthesizer.defaultModel,
    prefs.voiceName('openai') ?? 'nova',
  );
  consider(
    'elevenlabs',
    prefs.voiceModel('elevenlabs'),
    ElevenLabsTtsSynthesizer.defaultModel,
    prefs.voiceName('elevenlabs') ?? '21m00Tcm4TlvDq8ikWAM',
  );
  return out.toList();
});

/// Finds a chapter's narration in whichever voice it was saved with, so a
/// change of voice does not read as "the audio is gone".
final savedNarrationProvider = Provider<SavedNarration>(
  (ref) => SavedNarration(ref.watch(audioCacheProvider)),
);

/// On-disk cache of synthesized narration, so replays/re-opens are instant and
/// gap-free and don't re-hit the cloud. Shared across voice-provider rebuilds.
final audioCacheProvider = Provider<AudioCache>((ref) => FileAudioCache());

/// Where story pictures live on disk.
final pictureStoreProvider = Provider<PictureStore>(
  (ref) => FilePictureStore(resolve: LibraryPaths.pictures),
);

/// Draws pictures for a story. Never called by a story turn — a picture costs
/// more than the story it illustrates, so it happens when somebody asks.
final illustrationServiceProvider = Provider<IllustrationService>(
  (ref) => IllustrationService(
    illustrator: GeminiIllustrator(secrets: ref.watch(secretStoreProvider)),
    pictures: ref.watch(pictureStoreProvider),
    repo: ref.watch(storageRepoProvider),
  ),
);

/// The pictures a story has, newest last.
final storyImagesProvider = FutureProvider.family<List<StoryImage>, String>(
  (ref, seriesId) => ref.watch(storageRepoProvider).loadImages(seriesId),
);

/// The voice to read in, once the world has had its say.
///
/// A world keeps its own storyteller so every episode sounds like the same
/// person — that is most of what makes a world feel like a place rather than a
/// folder. Only the **name** is overridden: the engine stays whatever the
/// grown-up configured, because an engine needs a key and a consent, and a
/// world that could switch engines would be a world that could start spending
/// money on a provider nobody agreed to.
///
/// A world with no voice of its own, a device voice, or a name that does not
/// belong to the current engine all fall through to the parent's setting — the
/// last of those matters when the engine is changed after a world was named.
final storyVoiceProvider = Provider<VoiceConfig>((ref) {
  final cfg = ref.watch(voiceConfigProvider);
  final world = ref.watch(activeWorldProvider);
  final wanted = world?.voiceName.trim() ?? '';
  if (wanted.isEmpty || cfg.engine == VoiceEngine.device) return cfg;
  if (!voicesFor(cfg.engine).contains(wanted)) return cfg;
  return VoiceConfig(cfg.engine, wanted, cfg.model);
});

/// The voices an engine offers by name. One list, used by the parent's picker
/// in settings and by the child-facing one on a world.
List<String> voicesFor(VoiceEngine engine) => switch (engine) {
  VoiceEngine.gemini => GeminiTtsSynthesizer.voices,
  VoiceEngine.openai => OpenAiTtsSynthesizer.voices,
  VoiceEngine.elevenlabs => ElevenLabsTtsSynthesizer.presets.values.toList(),
  VoiceEngine.device => const [],
};

/// A reader for one named voice, for auditioning it.
///
/// Separate from [ttsProvider] on purpose: previewing a voice must not stop
/// the story currently being read, and must not become the story's voice just
/// because somebody tapped it. Shares the same cache, so hearing a voice twice
/// costs once.
final voicePreviewProvider = Provider.family<TtsProvider, String>((
  ref,
  voiceName,
) {
  final cfg = ref.watch(voiceConfigProvider);
  final provider = _readerFor(
    ref,
    VoiceConfig(cfg.engine, voiceName, cfg.model),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

/// The active voice reader — device TTS or a cloud engine. Disposed on rebuild.
final ttsProvider = Provider<TtsProvider>((ref) {
  final cfg = ref.watch(storyVoiceProvider);
  final provider = _readerFor(ref, cfg);
  ref.onDispose(provider.dispose);
  // Note the voice so a later cache lookup can still find what it recorded.
  // Fire-and-forget: this only ever adds to a list, and being a moment late
  // costs nothing — audio cannot be cached before the provider exists.
  if (cfg.engine != VoiceEngine.device) {
    AppPrefs.open().then(
      (p) => p.rememberVoiceSignature(provider.voiceSignature),
    );
  }
  return provider;
});

/// Build a reader for one configuration. The caller owns disposing it.
TtsProvider _readerFor(Ref ref, VoiceConfig cfg) {
  final secrets = ref.watch(secretStoreProvider);
  final cache = ref.watch(audioCacheProvider);
  return switch (cfg.engine) {
    VoiceEngine.openai => CloudTtsProvider(
      OpenAiTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty ? 'nova' : cfg.voiceName,
        model: cfg.model.isEmpty
            ? OpenAiTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.openai,
      cache: cache,
    ),
    VoiceEngine.elevenlabs => CloudTtsProvider(
      ElevenLabsTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty
            ? '21m00Tcm4TlvDq8ikWAM'
            : cfg.voiceName,
        model: cfg.model.isEmpty
            ? ElevenLabsTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.elevenlabs,
      cache: cache,
    ),
    VoiceEngine.gemini => CloudTtsProvider(
      GeminiTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty ? 'Kore' : cfg.voiceName,
        model: cfg.model.isEmpty
            ? GeminiTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.gemini,
      cache: cache,
    ),
    VoiceEngine.device => DeviceTtsProvider(),
  };
}

// ─── Storage ──────────────────────────────────────────────────────────

/// The on-device Drift database. Opened lazily; closed when disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  // path_provider lives here, on the Flutter side, so the database itself
  // stays reachable from a plain `dart run`.
  final db = AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, AppDatabase.fileName)),
      );
    }),
  );
  ref.onDispose(db.close);
  return db;
});

final storageRepoProvider = Provider<StorageRepo>(
  (ref) => DriftStorageRepo(ref.watch(databaseProvider)),
);

// ─── Domain services ──────────────────────────────────────────────────

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(storageRepoProvider)),
);

final quizServiceProvider = Provider<QuizService>(
  (ref) => QuizService(ref.watch(storageRepoProvider)),
);

final seriesServiceProvider = Provider<SeriesService>(
  (ref) => SeriesService(ref.watch(storageRepoProvider)),
);

final worldServiceProvider = Provider<WorldService>(
  (ref) => WorldService(ref.watch(storageRepoProvider)),
);

final characterServiceProvider = Provider<CharacterService>(
  (ref) => CharacterService(ref.watch(storageRepoProvider)),
);

/// Export/import stories as `.sleepy` files (text + audio + metadata).
final sleepyServiceProvider = Provider<SleepyService>(
  (ref) => SleepyService(
    ref.watch(storageRepoProvider),
    ref.watch(audioCacheProvider),
  ),
);

/// The child's worlds (the bookshelf). Invalidate after create/delete.
final worldsForChildProvider = FutureProvider.family<List<World>, String>(
  (ref, childId) => ref.watch(worldServiceProvider).forChild(childId),
);

/// A world's saved characters. Invalidate after create/edit/delete.
final charactersForWorldProvider =
    FutureProvider.family<List<StoryCharacter>, String>(
      (ref, worldId) => ref.watch(characterServiceProvider).forWorld(worldId),
    );

/// The currently open world (null = none / standalone).
final activeWorldProvider = NotifierProvider<ActiveWorld, World?>(
  ActiveWorld.new,
);

class ActiveWorld extends Notifier<World?> {
  @override
  World? build() => null;

  void select(World? world) => state = world;
}

/// Active (non-archived) series for a given child — the story library.
/// Invalidate after creating/archiving a series to refresh.
final seriesForChildProvider = FutureProvider.family<List<Series>, String>(
  (ref, childId) => ref.watch(seriesServiceProvider).forChild(childId),
);

/// The currently open series (null = none).
final activeSeriesProvider = NotifierProvider<ActiveSeries, Series?>(
  ActiveSeries.new,
);

class ActiveSeries extends Notifier<Series?> {
  @override
  Series? build() => null;

  void select(Series? series) => state = series;
}

/// All beats for a series, oldest→newest. Invalidate after a new turn.
final beatsForSeriesProvider = FutureProvider.family<List<Beat>, String>(
  (ref, seriesId) => ref.watch(storageRepoProvider).loadBeats(seriesId),
);

/// All child profiles. Invalidate after create/edit/delete to refresh the UI.
final profilesProvider = FutureProvider<List<ChildProfile>>(
  (ref) => ref.watch(profileServiceProvider).all(),
);

/// The currently selected child (null = none chosen yet).
final activeChildProvider = NotifierProvider<ActiveChild, ChildProfile?>(
  ActiveChild.new,
);

class ActiveChild extends Notifier<ChildProfile?> {
  @override
  ChildProfile? build() => null;

  void select(ChildProfile? child) => state = child;
}

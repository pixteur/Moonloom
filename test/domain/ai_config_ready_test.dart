import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/ai/ai_provider.dart';
import 'package:moonloom/adapters/ai/fake_ai_provider.dart';
import 'package:moonloom/adapters/ai/gemini_provider.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real provider configured, and a story written by the fake one anyway.
///
/// Reported as "a new story from a world gives me Naming it… with six
/// identical chapters", and the six chapters were the fake provider's canned
/// line, word for word. The settings were right — consent given, Gemini
/// chosen, key stored. The provider that reads them answers `fake` at once
/// and loads the real choice behind it, and the chapter screen captured the
/// engine in that window and kept it for all six chapters. The fake provider
/// does not fail; it succeeds with canned text. So there was no warning, and
/// the story was never named.
class _KeyFor implements SecretStore {
  _KeyFor(this.provider);
  final String provider;

  @override
  Future<String?> readKey(String id) async => id == provider ? 'k' : null;
  @override
  Future<bool> hasKey(String id) async => id == provider;
  @override
  Future<void> writeKey(String id, String key) async {}
  @override
  Future<void> deleteKey(String id) async {}
}

void main() {
  late ProviderContainer container;

  setUp(() {
    // Exactly the settings on the machine it was reported from.
    SharedPreferences.setMockInitialValues({
      'ai_third_party_consent': true,
      'selected_provider': 'gemini',
    });
    container = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(_KeyFor(GeminiProvider.keyName)),
      ],
    );
  });

  tearDown(() => container.dispose());

  // The window itself. This is why the fix is to wait, not to read harder.
  test('read straight away, the provider is still the fake one', () async {
    expect(container.read(aiConfigProvider), ProviderId.fake);
    expect(container.read(aiProvider), isA<FakeAiProvider>());
    // Let the load land before the container goes, or it writes to a provider
    // that has already been disposed.
    await container.read(aiConfigProvider.notifier).ready;
  });

  test('once ready, it is the provider the grown-up chose', () async {
    await container.read(aiConfigProvider.notifier).ready;
    expect(container.read(aiConfigProvider), ProviderId.gemini);
    expect(container.read(aiProvider), isA<GeminiProvider>());
  });

  test('the engine taken after ready is not on the fake provider', () async {
    final early = container.read(storyEngineProvider);
    await container.read(aiConfigProvider.notifier).ready;
    final late = container.read(storyEngineProvider);
    expect(
      identical(early, late),
      isFalse,
      reason: 'an engine captured early is the one that wrote six fakes',
    );
  });

  // The placeholder answers instantly and successfully, so the app has to say
  // why it is being used — every reason in words a grown-up can act on.
  group('why the placeholder is writing', () {
    Future<String> whyWith(Map<String, Object> prefs, {String? key}) async {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer(
        overrides: [
          secretStoreProvider.overrideWithValue(_KeyFor(key ?? 'none')),
        ],
      );
      addTearDown(c.dispose);
      await c.read(aiConfigProvider.notifier).ready;
      return c.read(aiConfigProvider.notifier).why;
    }

    test('no permission given', () async {
      expect(
        await whyWith({'selected_provider': 'gemini'}),
        contains('permission'),
      );
    });

    test('no key saved', () async {
      expect(
        await whyWith({
          'ai_third_party_consent': true,
          'selected_provider': 'gemini',
        }),
        contains('no key'),
      );
    });

    test('a working setup says what it is using', () async {
      expect(
        await whyWith({
          'ai_third_party_consent': true,
          'selected_provider': 'gemini',
        }, key: GeminiProvider.keyName),
        'using gemini',
      );
    });
  });

  // The fake provider still has a job: no consent or no key really does mean
  // canned stories, offline. Waiting must not turn that into a real call.
  test('without consent it stays fake after loading too', () async {
    SharedPreferences.setMockInitialValues({'selected_provider': 'gemini'});
    final noConsent = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(_KeyFor(GeminiProvider.keyName)),
      ],
    );
    addTearDown(noConsent.dispose);
    await noConsent.read(aiConfigProvider.notifier).ready;
    expect(noConsent.read(aiConfigProvider), ProviderId.fake);
  });
}

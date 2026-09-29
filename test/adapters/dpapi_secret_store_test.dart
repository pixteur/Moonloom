@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonloom/adapters/secrets/dpapi_secret_store.dart';

/// Windows-only: exercises the real DPAPI FFI round-trip. CI (Linux) skips this
/// file via @TestOn; it runs on a developer's Windows machine.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('encrypts, stores, and reads back an API key', () async {
    final store = DpapiSecretStore();
    expect(await store.hasKey('claude'), isFalse);

    await store.writeKey('claude', 'sk-ant-secret-123');
    expect(await store.hasKey('claude'), isTrue);
    expect(await store.readKey('claude'), 'sk-ant-secret-123');

    await store.deleteKey('claude');
    expect(await store.hasKey('claude'), isFalse);
    expect(await store.readKey('claude'), isNull);
  });
}

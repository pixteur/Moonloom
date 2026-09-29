import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/app.dart';
import 'package:moonloom/app_providers.dart';

import 'support/in_memory_storage_repo.dart';

void main() {
  testWidgets('App boots to the profile select / welcome screen', (
    tester,
  ) async {
    // Override storage with the in-memory repo so the boot path never touches
    // Drift / native sqlite / path_provider in tests.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageRepoProvider.overrideWithValue(InMemoryStorageRepo()),
        ],
        child: const MoonloomApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Fresh repo → empty state welcome.
    expect(find.text('Welcome to MoonloomApp'), findsOneWidget);
    expect(find.text('Add a child'), findsOneWidget);
  });
}

import 'package:flutter/material.dart' hide HeroMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/ai/fake_ai_provider.dart';
import 'package:moonloom/app_providers.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';
import 'package:moonloom/ui/series/new_series_screen.dart';

import '../support/in_memory_storage_repo.dart';

/// "New episode" opened from inside a world, with a real cast, the way a
/// grown-up reaches it — rather than the cast strip on its own.
void main() {
  const child = ChildProfile(id: 'c1', displayName: 'Mia', age: 5);
  const world = World(id: 'w1', childId: 'c1', name: "Pip's Adventures");

  late InMemoryStorageRepo repo;
  late ProviderContainer container;

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveProfile(child);
    await repo.saveWorld(world);
    for (final c in const [
      StoryCharacter(
        id: 'p',
        worldId: 'w1',
        name: 'Pip',
        description: 'axolotl',
      ),
      StoryCharacter(
        id: 'b',
        worldId: 'w1',
        name: 'Barnaby',
        description: 'crab',
      ),
    ]) {
      await repo.saveCharacter(c);
    }
    container = ProviderContainer(
      overrides: [
        storageRepoProvider.overrideWithValue(repo),
        // The chapter screen starts writing chapter 1 the moment it opens. A
        // real model there means network calls that outlive the test and
        // bleed into the next one, so it passed alone and failed in a group.
        aiProvider.overrideWithValue(FakeAiProvider()),
      ],
    );
    container.read(activeChildProvider.notifier).select(child);
    container.read(activeWorldProvider.notifier).select(world);
  });

  tearDown(() => container.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(407, 2400));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewSeriesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens without an error', (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('New episode'), findsOneWidget);
  });

  testWidgets('shows the cast', (tester) async {
    await open(tester);
    expect(find.text('Pip'), findsOneWidget);
    expect(find.text('Barnaby'), findsOneWidget);
  });

  testWidgets('tapping a face makes them the hero', (tester) async {
    await open(tester);
    await tester.tap(find.text('Pip'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Pip'), findsOneWidget);
  });
}

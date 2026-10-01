import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/app_providers.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/ui/series/world_cast_strip.dart';

import '../support/in_memory_storage_repo.dart';

/// The cast a world carries, shown on the screen that promises it carries one.
///
/// "New episode" said the characters carry over and then showed none of them,
/// so a grown-up had to remember who was in the world and type a name into a
/// box. A request for Pip went in as "PIP", matched nothing the world had
/// saved, and came back as a story about somebody else. These pin the two
/// things that fixes: the names are visible, and tapping one answers with the
/// spelling the world uses rather than the one that was typed.
void main() {
  late InMemoryStorageRepo repo;

  const cast = [
    StoryCharacter(
      id: 'c1',
      worldId: 'w1',
      name: 'Pip',
      description: 'axolotl',
    ),
    StoryCharacter(id: 'c2', worldId: 'w1', name: 'Barnaby'),
    StoryCharacter(id: 'c3', worldId: 'w1', name: 'Cœur'),
  ];

  setUp(() async {
    repo = InMemoryStorageRepo();
    for (final character in cast) {
      await repo.saveCharacter(character);
    }
  });

  /// The strip on its own, with the repo the world's cast comes from.
  Future<void> pump(
    WidgetTester tester, {
    String selected = '',
    ValueChanged<String?>? onPick,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageRepoProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: WorldCastStrip(
              worldId: 'w1',
              selected: selected,
              onPick: onPick ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every character in the world is named', (tester) async {
    await pump(tester);
    expect(find.text('Pip'), findsOneWidget);
    expect(find.text('Barnaby'), findsOneWidget);
    expect(find.text('Cœur'), findsOneWidget);
  });

  testWidgets('a world with nobody in it takes no room at all', (tester) async {
    repo = InMemoryStorageRepo();
    await pump(tester);
    expect(find.text('Who is in this world'), findsNothing);
  });

  // The whole point of the strip. A name typed by hand reaches the prompt as
  // typed; a name tapped reaches it as the world spells it, which is what the
  // cast list the model is given says.
  testWidgets("tapping answers with the world's own spelling", (tester) async {
    String? picked;
    await pump(tester, onPick: (name) => picked = name);
    await tester.tap(find.text('Cœur'));
    expect(picked, 'Cœur');
  });

  testWidgets('tapping the chosen one again unpicks them', (tester) async {
    String? picked = 'unset';
    // Lower case on purpose: a grown-up half-way through typing "pip" has
    // already picked Pip, and the face has to agree.
    await pump(tester, selected: 'pip', onPick: (name) => picked = name);
    await tester.tap(find.text('Pip'));
    expect(picked, isNull);
  });

  // A character usually exists before their drawing does, and a world that
  // showed empty squares until every sheet was paid for would look broken.
  testWidgets('a character with no drawing still shows', (tester) async {
    await pump(tester);
    expect(find.text('B'), findsOneWidget, reason: "Barnaby's initial");
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('the row scrolls rather than overflowing', (tester) async {
    repo = InMemoryStorageRepo();
    for (var i = 0; i < 12; i++) {
      await repo.saveCharacter(
        StoryCharacter(id: 'c$i', worldId: 'w1', name: 'Character$i'),
      );
    }
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });
}

/// "A new story from a world gives me Naming it… with six identical chapters."
///
/// Two explanations were tried and both were wrong, because both were checked
/// in isolation: a probe that resolved the settings by itself, and widget tests
/// that mock the very plugins in question. This runs the real app — the real
/// `main()`, the real settings file, the real secret store — and walks the path
/// a grown-up walks: pick the child, open the bookshelf, open a world, start a
/// new episode, build it. Then it says which provider the app held at that
/// moment and what was actually written.
///
///     flutter test integration_test/new_episode_real_test.dart -d windows
///
/// It writes one real story to the library and spends one real chapter's
/// worth of API calls. It prints the story's id so it can be removed with
/// `tool/delete_series.dart --id <id> --write`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moonloom/app.dart';
import 'package:moonloom/app_providers.dart';
import 'package:moonloom/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new episode in a real world is written by the real model', (
    tester,
  ) async {
    void say(String s) => debugPrint('REAL $s');

    Future<void> settle([int seconds = 2]) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapText(String text) async {
      final f = find.text(text);
      // A long form builds lazily: a button below the fold does not exist yet,
      // so scroll it into being before deciding it is missing.
      if (f.evaluate().isEmpty &&
          find.byType(Scrollable).evaluate().isNotEmpty) {
        try {
          await tester.scrollUntilVisible(
            f,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        } catch (_) {}
      }
      if (f.evaluate().isEmpty) {
        final shown = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .where((s) => s.trim().isNotEmpty)
            .take(30)
            .join(' | ');
        say('could not find "$text". On screen: $shown');
        fail('no "$text" on screen');
      }
      await tester.ensureVisible(f.first);
      await tester.tap(f.first);
      await settle();
      say('tapped "$text"');
    }

    await app.main();
    await settle(4);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MoonloomApp)),
    );
    say(
      'at launch  config=${container.read(aiConfigProvider)}  '
      'ai=${container.read(aiProvider).runtimeType}',
    );

    await tapText('Mia');
    await tapText('Bookshelf');
    await tapText("Pip's Adventures");
    await tapText('New episode');

    say(
      'before build  config=${container.read(aiConfigProvider)}  '
      'ai=${container.read(aiProvider).runtimeType}  '
      'model="${container.read(textModelProvider)}"',
    );

    final repo = container.read(storageRepoProvider);
    final child = container.read(activeChildProvider)!;
    // The new story is whichever one was not there before the tap.
    final before = {for (final s in await repo.loadSeries(child.id)) s.id};

    await tapText('Build episode');

    // Chapter 1, plus its editorial pass, from a real model: give it time.
    String? id;
    String? summary;
    for (var waited = 0; waited < 120 && summary == null; waited++) {
      await settle(1);
      final fresh = (await repo.loadSeries(
        child.id,
      )).where((s) => !before.contains(s.id)).toList();
      if (fresh.isEmpty) continue;
      id = fresh.first.id;
      final beats = await repo.loadBeats(id);
      if (beats.isNotEmpty) summary = beats.first.summary;
    }

    say(
      'after build  config=${container.read(aiConfigProvider)}  '
      'ai=${container.read(aiProvider).runtimeType}',
    );
    say('story id   $id');
    say('chapter 1  $summary');
    expect(
      summary,
      isNot('The gentle path home and a peaceful goodnight.'),
      reason: 'that is the fake provider, word for word',
    );
  });
}

/// Remove a child and everything of theirs.
///
/// **The most destructive thing in this repository.** A child's whole library
/// goes: every story, every chapter, their worlds, the cast in them, the
/// pictures, the quiz answers. The app puts this behind a hold and a double
/// confirmation for good reason, and this exists only for the times the app
/// is not the right place to do it from.
///
/// So it counts first and asks second. Dry run unless `--write`, and the dry
/// run prints the tally the app's own confirmation would show, because a
/// number is the only thing that makes "everything of theirs" concrete.
///
///     dart run tool/delete_child.dart --child Gabriel
///     dart run tool/delete_child.dart --child Gabriel --write
///
/// Picture files are named by content and shared between stories, so they are
/// left on disk: deleting one that another child's story still points at would
/// turn their cover into a blank square. A few megabytes is the cheaper
/// mistake.
library;

import 'dart:io';

import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final name = _opt(args, '--child');
  if (name == null) {
    stdout.writeln('Which child? Pass --child <name>.');
    return;
  }

  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE'] ?? ''}'
    r'\Documents',
  );
  final repo = DriftStorageRepo(db);

  final children = await repo.loadProfiles();
  final child = children
      .where((c) => c.displayName.toLowerCase() == name.toLowerCase())
      .firstOrNull;
  if (child == null) {
    stdout.writeln(
      'No child called "$name". There is: '
      '${children.map((c) => c.displayName).join(', ')}.',
    );
    await db.close();
    return;
  }

  // Counted before anything is touched, so the tally is of what actually
  // exists rather than of what a cascade is assumed to reach.
  final stories = await repo.loadSeries(child.id);
  final worlds = await repo.loadWorlds(child.id);
  var chapters = 0;
  var images = 0;
  for (final story in stories) {
    chapters += (await repo.loadBeats(story.id)).length;
    images += (await repo.loadImages(story.id)).length;
  }
  var cast = 0;
  for (final world in worlds) {
    cast += (await repo.loadCharacters(world.id)).length;
  }

  stdout.writeln('${child.displayName}, aged ${child.age}');
  stdout.writeln('  ${stories.length} stories, $chapters chapters');
  stdout.writeln('  ${worlds.length} worlds, $cast characters');
  stdout.writeln('  $images pictures');

  if (!write) {
    stdout.writeln(
      '\nNothing deleted. Add --write to remove ${child.displayName} and all '
      'of the above. This cannot be undone.',
    );
    await db.close();
    return;
  }

  await repo.deleteProfile(child.id);

  // Read back rather than trusting the cascade. A foreign key that was not
  // declared ON DELETE CASCADE fails silently here, leaving orphaned rows that
  // surface much later as a story belonging to nobody.
  final left = (await repo.loadProfiles())
      .where((c) => c.id == child.id)
      .length;
  final orphanStories = (await repo.loadSeries(child.id)).length;
  stdout.writeln(
    left == 0 && orphanStories == 0
        ? '\n${child.displayName} removed, along with '
              '${stories.length} stories and ${worlds.length} worlds.'
        : '\nSomething is left behind: $left profile rows, '
              '$orphanStories stories. The cascade did not reach everything.',
  );
  await db.close();
}

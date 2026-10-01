/// Teach existing worlds who lives in them.
///
/// Every chapter has always recorded its characters; nothing ever promoted
/// them into the world, so each new episode started with an empty cast list.
/// The engine does that now — but the stories already written still have
/// nobody saved, and the next episode in an old world would invent its cast
/// all over again.
///
/// This reads the chapters each world already has and saves the people in
/// them. The EARLIEST description wins: the first story is the one that
/// decided what Pip was, and the later ones are the drift.
///
///     dart run tool/backfill_cast.dart            # show what would be saved
///     dart run tool/backfill_cast.dart --write
library;

import 'dart:io';

import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/cast_line.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final at = args.indexOf('--world');
  final only = at >= 0 && at + 1 < args.length ? args[at + 1] : null;
  final db = AppDatabase.openIn(
    r''
    '${Platform.environment['USERPROFILE']}'
    r'\Documents',
  );
  final repo = DriftStorageRepo(db);
  const uuid = Uuid();
  var added = 0;

  for (final child in await repo.loadProfiles()) {
    for (final world in await repo.loadWorlds(child.id)) {
      // One world at a time by default, because the past is messy: a world
      // whose stories drifted has three spellings of the same character, and
      // importing all of them locks the drift in rather than ending it.
      if (only != null &&
          !world.name.toLowerCase().contains(only.toLowerCase())) {
        continue;
      }
      final known = await repo.loadCharacters(world.id);
      final seen = {for (final c in known) foldedName(c.name)};
      // Oldest first: whoever the first story met is who they are.
      final episodes = (await repo.loadSeries(
        child.id,
      )).where((s) => s.worldId == world.id).toList();
      // Keyed case-insensitively: "Bébé hibou" and "bébé hibou" are one owl.
      final found = <String, String>{};
      final canonical = <String, String>{};
      // Per character, whether any chapter wrote their name as a name rather
      // than as a description of them.
      final readsAsName = <String, bool>{};
      for (final episode in episodes) {
        for (final beat in await repo.loadBeats(episode.id)) {
          for (final entry in beat.characters) {
            final (name, description) = parseCastEntry(entry);
            if (name.isEmpty) continue;
            final key = foldedName(name);
            if (key.isEmpty || seen.contains(key)) continue;

            // Whether this is a character is decided per *character*, not per
            // spelling. Chapters disagree about capitals — "Blue Tangs" in one
            // and "Blue tangs (fish)" in the next — and testing each spelling
            // on its own threw away the only mention that said what they were
            // while keeping the one that did not. So every spelling is
            // gathered, and the question is asked once at the end.
            readsAsName[key] =
                (readsAsName[key] ?? false) || !isDescriptionNotName(name);
            // The best-capitalised spelling is the one worth saving.
            final best = canonical[key];
            if (best == null ||
                (isDescriptionNotName(best) && !isDescriptionNotName(name))) {
              canonical[key] = name;
            }
            // First description wins; a later, emptier mention adds nothing.
            final existing = found[key];
            if (existing == null ||
                (existing.isEmpty && description.isNotEmpty)) {
              found[key] = tidyDescription(description);
            }
          }
        }
      }
      // "The baby dragon" and "Iridescent fish" are not people, they are
      // sentences that lost their subject — the prose names that dragon Oliver
      // two paragraphs later. Saving them gave a world somebody nobody is.
      found.removeWhere((key, _) => readsAsName[key] != true);
      if (found.isEmpty) continue;
      stdout.writeln('${child.displayName} / ${world.name}');
      for (final entry in found.entries.take(12)) {
        final shown = canonical[entry.key] ?? entry.key;
        stdout.writeln(
          '  ${shown.padRight(16)} '
          '${entry.value.isEmpty ? '(no description recorded)' : entry.value}',
        );
        added++;
        if (write) {
          await repo.saveCharacter(
            StoryCharacter(
              id: uuid.v4(),
              worldId: world.id,
              name: canonical[entry.key] ?? entry.key,
              description: entry.value,
            ),
          );
        }
      }
    }
  }

  stdout.writeln(
    added == 0
        ? '\nEvery world already knows its cast.'
        : write
        ? '\nSaved $added characters. Check them in "Edit world" — the '
              'earliest description won, and the earliest story is not always '
              'the one you wanted.'
        : '\n$added characters would be saved. Re-run with --write.',
  );
  await db.close();
}

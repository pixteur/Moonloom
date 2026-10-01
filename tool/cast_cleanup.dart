/// Tidy the people a world remembers.
///
/// A world's cast is assembled from what each chapter recorded about itself,
/// and chapters were written before anything parsed them. So the list drifts
/// in four ways, all visible in the real library:
///
///   * **A description saved as a name.** "The baby dragon" and "Iridescent
///     fish" are not names; the prose calls that dragon Oliver and uses
///     "iridescent" as an adjective. The world then holds a character nobody
///     is, and a story's device portrait can be drawn of them.
///   * **The same character twice.** "Cœur" and "Coeur" are one dragon as far
///     as a child is concerned and two rows as far as the database is, so the
///     prompt carries both and teaches the model there are two.
///   * **Descriptions that disagree about articles.** "a crab" beside
///     "axolotl" — harmless alone, but the cast list is pasted into every
///     prompt, and a list that reads as though several people wrote it is one
///     the model treats as several people's work.
///   * **Control characters.** A NUL inside a name made one character
///     unmatchable and untypeable. [parseCastEntry] strips them now; the rows
///     written before it did are still there.
///
/// The mechanical ones this fixes on its own. The judgment ones it only
/// reports, with the evidence — merging "The baby dragon" into Oliver is a
/// claim about a story, and this file has no business making it. Pass the
/// merge explicitly once you have read the prose it prints.
///
///     dart run tool/cast_cleanup.dart                       # what is wrong
///     dart run tool/cast_cleanup.dart --write               # fix the safe ones
///     dart run tool/cast_cleanup.dart --merge "The baby dragon" --into Oliver
///
/// Dry run unless `--write`. A merge keeps the survivor's description and
/// adopts the loser's reference sheet only when the survivor has none, so a
/// drawing that was paid for is never thrown away.
library;

import 'dart:io';

import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/cast_line.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

/// The comparison, the description test and the description tidy all come from
/// [cast_line.dart] rather than being written again here. They have to be the
/// same rules the engine applies when it saves a character and the ones
/// `backfill_cast` applies when it reads the past — three tools disagreeing
/// about who is who is how a cleanup gets undone by the next backfill.
String _tidyName(String raw) =>
    raw.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final mergeFrom = _opt(args, '--merge');
  final mergeInto = _opt(args, '--into');
  final onlyWorld = _opt(args, '--world');

  final db = AppDatabase.openIn(
    '${Platform.environment['USERPROFILE']}\\Documents',
  );
  final repo = DriftStorageRepo(db);

  if ((mergeFrom == null) != (mergeInto == null)) {
    stdout.writeln('--merge needs --into.');
    await db.close();
    return;
  }

  var changed = 0;
  var flagged = 0;

  for (final child in await repo.loadProfiles()) {
    for (final world in await repo.loadWorlds(child.id)) {
      if (onlyWorld != null &&
          world.name.toLowerCase() != onlyWorld.toLowerCase()) {
        continue;
      }
      final cast = await repo.loadCharacters(world.id);
      if (cast.isEmpty) continue;
      stdout.writeln('\n${world.name}  (${cast.length})');

      // ── An explicit merge, named by a person who read the stories ──
      if (mergeFrom != null) {
        final loser = cast.cast<StoryCharacter?>().firstWhere(
          (c) => foldedName(c!.name) == foldedName(mergeFrom),
          orElse: () => null,
        );
        final keeper = cast.cast<StoryCharacter?>().firstWhere(
          (c) => foldedName(c!.name) == foldedName(mergeInto!),
          orElse: () => null,
        );
        if (loser != null && keeper != null) {
          // The sheet is the expensive part and the only copy there will be,
          // so it is adopted rather than dropped — but never over one the
          // survivor already has, which is the drawing the stories have been
          // drawn against.
          final adopt =
              keeper.sheetFileKey.isEmpty && loser.sheetFileKey.isNotEmpty;
          stdout.writeln(
            '  merge "${loser.name}" into "${keeper.name}"'
            '${adopt ? ', keeping ${loser.name}\'s sheet' : ''}',
          );
          if (write) {
            if (adopt) {
              await repo.saveCharacter(
                keeper.copyWith(sheetFileKey: loser.sheetFileKey),
              );
            }
            await repo.deleteCharacter(loser.id);
          }
          changed++;
          continue;
        }
      }

      // ── The mechanical repairs ──
      final kept = <String, StoryCharacter>{};
      for (final character in cast) {
        final name = _tidyName(character.name);
        final description = tidyDescription(character.description);
        final key = foldedName(name);
        if (key.isEmpty) {
          stdout.writeln('  drop "${character.name}" — no usable name');
          if (write) await repo.deleteCharacter(character.id);
          changed++;
          continue;
        }

        final existing = kept[key];
        if (existing == null) {
          kept[key] = character;
          if (name != character.name || description != character.description) {
            stdout.writeln(
              '  tidy  "${character.name}" / "${character.description}" '
              '→ "$name" / "$description"',
            );
            if (write) {
              await repo.saveCharacter(
                character.copyWith(name: name, description: description),
              );
            }
            changed++;
          }
          continue;
        }

        // The same person twice. The one with more to say about themselves
        // survives; a row saying only "Coeur" tells a prompt nothing.
        final keeper =
            existing.description.trim().length >= description.trim().length
            ? existing
            : character;
        final loser = identical(keeper, existing) ? character : existing;
        kept[key] = keeper;
        stdout.writeln(
          '  same  "${loser.name}" is "${keeper.name}" — removing the duplicate',
        );
        if (write) {
          if (keeper.sheetFileKey.isEmpty && loser.sheetFileKey.isNotEmpty) {
            await repo.saveCharacter(
              keeper.copyWith(sheetFileKey: loser.sheetFileKey),
            );
          }
          await repo.deleteCharacter(loser.id);
        }
        changed++;
      }

      // ── The judgment calls, reported with their evidence ──
      for (final character in kept.values) {
        if (!isDescriptionNotName(character.name)) continue;
        flagged++;
        stdout.writeln(
          '  ?     "${character.name}" reads as a description, not a name',
        );
        for (final line in await _evidence(repo, world, character.name)) {
          stdout.writeln('          $line');
        }
      }
    }
  }

  stdout.writeln(
    '\n$changed change${changed == 1 ? '' : 's'}'
    '${write ? ' written' : ' (dry run — re-run with --write)'}'
    '${flagged == 0 ? '' : ', $flagged name${flagged == 1 ? '' : 's'} need a '
              'person to decide'}.',
  );
  await db.close();
}

/// What the stories actually say near a doubtful name.
///
/// The point of printing it rather than acting on it: "The baby dragon" turns
/// out to be Oliver, and the only way to know that is to read the sentence
/// where the story says so.
Future<List<String>> _evidence(
  DriftStorageRepo repo,
  World world,
  String name,
) async {
  final needle = name.toLowerCase().replaceAll(RegExp(r'^(the|a|an)\s+'), '');
  final out = <String>[];
  for (final series in await repo.loadSeries(world.childId)) {
    if (series.worldId != world.id) continue;
    for (final beat in await repo.loadBeats(series.id)) {
      for (final sentence in beat.text.split(RegExp(r'(?<=[.!?])\s+'))) {
        if (!sentence.toLowerCase().contains(needle)) continue;
        final tidy = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (tidy.length > 160) continue;
        out.add(tidy);
        if (out.length >= 3) return out;
      }
    }
  }
  return out;
}

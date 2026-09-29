/// Add a character to a world, so their reference sheet can be drawn.
///
/// A world with no saved cast gets no character sheets, and without sheets
/// every picture invents the character again — which is the whole problem.
///
///     dart run tool/add_character.dart --child Mia --world "Pip's Adventures" \
///         --name Pip --description "a small red fox with a bushy tail"
library;

import 'dart:io';

import 'package:moonloom/adapters/storage/app_database.dart';
import 'package:moonloom/adapters/storage/drift_storage_repo.dart';
import 'package:moonloom/domain/cast_line.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/domain/models/world.dart';
import 'package:uuid/uuid.dart';

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

Future<void> main(List<String> args) async {
  final db = AppDatabase.openIn(
    r''
    '${Platform.environment['USERPROFILE']}'
    r'\Documents',
  );
  final repo = DriftStorageRepo(db);
  final childName = _opt(args, '--child') ?? 'Mia';
  final worldName = _opt(args, '--world');
  final name = _opt(args, '--name');
  final description = _opt(args, '--description') ?? '';

  final kids = await repo.loadProfiles();
  final child = kids.firstWhere(
    (c) => c.displayName.toLowerCase() == childName.toLowerCase(),
  );
  final worlds = await repo.loadWorlds(child.id);
  // Matched loosely and reported clearly. An exact match threw "No element"
  // on "Mystical Creature" because the world is called "Mystical Creature
  // World", which is a stack trace where a sentence would do.
  final world = worldName == null
      ? worlds.first
      : worlds.cast<World?>().firstWhere(
          (w) => w!.name.toLowerCase().contains(worldName.toLowerCase()),
          orElse: () => null,
        );
  if (world == null) {
    stdout.writeln(
      'No world of ${child.displayName}\'s matching "$worldName". '
      'They have: ${worlds.map((w) => w.name).join(', ')}.',
    );
    await db.close();
    return;
  }

  if (name == null) {
    final cast = await repo.loadCharacters(world.id);
    stdout.writeln('${world.name} cast:');
    for (final c in cast) {
      stdout.writeln(
        '  ${c.name.padRight(12)} ${c.description}'
        '${c.sheetFileKey.isEmpty ? '' : '  [sheet ${c.sheetFileKey}]'}',
      );
    }
    if (cast.isEmpty) stdout.writeln('  (none)');
    await db.close();
    return;
  }

  // Removing somebody. Backfilling a world from drift-era stories imports
  // three spellings of one character and a few things that were never
  // characters at all — "leopard shark pup" as a name, somebody "referred to
  // but not present". A crowded cast list stops steering, so pruning it is
  // part of setting it.
  if (args.contains('--remove')) {
    // Compared on the sanitised name, so a row whose name carries a control
    // character — which no prompt can type — is still reachable.
    final wanted = parseCastEntry(name).$1.toLowerCase();
    final gone = (await repo.loadCharacters(
      world.id,
    )).where((c) => parseCastEntry(c.name).$1.toLowerCase() == wanted).toList();
    for (final c in gone) {
      await repo.deleteCharacter(c.id);
    }
    stdout.writeln(
      gone.isEmpty
          ? 'No $name in ${world.name}.'
          : 'Removed $name from ${world.name}.',
    );
    await db.close();
    return;
  }

  // Correcting somebody who is already here keeps their id, so nothing that
  // refers to them breaks — and drops their reference sheet, because a sheet
  // drawn from the old description is now a picture of the wrong animal.
  final existing = (await repo.loadCharacters(
    world.id,
  )).where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;

  if (existing != null) {
    await repo.saveCharacter(
      StoryCharacter(
        id: existing.id,
        worldId: world.id,
        name: name,
        description: description,
      ),
    );
    stdout.writeln(
      'Corrected $name in ${world.name}:\n'
      '  was: ${existing.description.isEmpty ? '(nothing)' : existing.description}\n'
      '  now: $description'
      '${existing.sheetFileKey.isEmpty ? '' : '\n  reference sheet dropped — '
                'it was drawn from the old description'}',
    );
    await db.close();
    return;
  }

  await repo.saveCharacter(
    StoryCharacter(
      id: const Uuid().v4(),
      worldId: world.id,
      name: name,
      description: description,
    ),
  );
  stdout.writeln('Added $name to ${world.name}.');
  await db.close();
}

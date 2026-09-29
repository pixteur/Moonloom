/// Add a character to a world, so their reference sheet can be drawn.
///
/// A world with no saved cast gets no character sheets, and without sheets
/// every picture invents the character again — which is the whole problem.
///
///     dart run tool/add_character.dart --child Mia --world "Pip's Adventures" \
///         --name Pip --description "a small red fox with a bushy tail"
library;

import 'dart:io';

import 'package:sleepytime/adapters/storage/app_database.dart';
import 'package:sleepytime/adapters/storage/drift_storage_repo.dart';
import 'package:sleepytime/domain/models/story_character.dart';
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
  final world = worldName == null
      ? worlds.first
      : worlds.firstWhere(
          (w) => w.name.toLowerCase() == worldName.toLowerCase(),
        );

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

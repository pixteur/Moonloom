/// Read-only: did the v10 migration actually add `worlds.voice_name`?
///
/// The migration trap this repo has already paid for once: branches share one
/// database in the documents folder, so a version can be stamped without the
/// step that number implies ever running, and the missing column surfaces far
/// away as a null-check crash. In-memory tests cannot catch it — they go
/// through onCreate and always get every column. So ask the real file.
///
///     dart run tool/world_voice_check.dart [--db path]
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final at = args.indexOf('--db');
  final path = at >= 0 && at + 1 < args.length
      ? args[at + 1]
      : r''
            '${Platform.environment['USERPROFILE']}'
            r'\Documents\sleepytime.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);

  final version = db.select('pragma user_version').first['user_version'];
  stdout.writeln('user_version: $version');

  final columns = db
      .select('pragma table_info(worlds)')
      .map((r) => r['name'] as String)
      .toList();
  stdout.writeln('worlds columns: ${columns.join(', ')}');
  stdout.writeln(
    columns.contains('voice_name')
        ? 'voice_name: PRESENT'
        : 'voice_name: MISSING — the migration did not run',
  );

  if (columns.contains('voice_name')) {
    for (final w in db.select('select name, voice_name from worlds')) {
      final v = (w['voice_name'] as String?) ?? '';
      stdout.writeln('  ${w['name']}: ${v.isEmpty ? '(parent setting)' : v}');
    }
  }
  db.close();
}

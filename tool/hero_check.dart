/// Read-only: what the "hero" choice actually saved, and who the world's cast
/// says the recurring characters are. Written to check a report that a named
/// character never shows up in the story.
///
///     dart run tool/hero_check.dart [childName]
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final at = args.indexOf('--db');
  final path = at >= 0 && at + 1 < args.length
      ? args[at + 1]
      : '${Platform.environment['USERPROFILE']}\\Documents\\sleepytime.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  final rest = [
    for (var i = 0; i < args.length; i++)
      if (i != at && i != at + 1) args[i],
  ];
  final want = rest.isNotEmpty ? rest.first.toLowerCase() : null;

  for (final kid in db.select('select id, display_name from child_profiles')) {
    final name = kid['display_name'] as String;
    if (want != null && name.toLowerCase() != want) continue;
    stdout.writeln('\n=== $name ===');
    final series = db.select(
      'select title, hero_mode, hero_name, world_id, seed_summary '
      'from series where child_id = ? order by created_at',
      [kid['id']],
    );
    for (final s in series) {
      stdout.writeln(
        '  "${s['title']}"  heroMode=${s['hero_mode']} '
        'heroName=${s['hero_name'] ?? '-'}',
      );
    }
  }

  stdout.writeln('\n=== worlds ===');
  for (final w in db.select('select name, cast_list from worlds')) {
    final cast = (w['cast_list'] as String?) ?? '';
    stdout.writeln('  ${w['name']}: ${cast.isEmpty ? '(none)' : cast}');
  }
  db.close();
}

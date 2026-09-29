/// Read-only: did the v11 migration land, and what pictures does the library
/// actually hold? Same reason as `tool/world_voice_check.dart` — an in-memory
/// test goes through onCreate and always has every table, so only the real
/// file can say whether the migration ran.
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

  stdout.writeln(
    'user_version: ${db.select('pragma user_version').first['user_version']}',
  );
  final tables = db
      .select("select name from sqlite_master where type='table'")
      .map((r) => r['name'] as String);
  stdout.writeln(
    tables.contains('story_images')
        ? 'story_images: PRESENT'
        : 'story_images: MISSING — the migration did not run',
  );
  if (!tables.contains('story_images')) {
    db.close();
    return;
  }

  final rows = db.select(
    'select s.title, i.kind, i.size, i.aspect, i.model, i.seed, '
    'length(i.prompt) as prompt_len, i.file_key '
    'from story_images i join series s on s.id = i.series_id '
    'order by s.title, i.kind',
  );
  stdout.writeln('\n${rows.length} pictures');
  for (final r in rows) {
    stdout.writeln(
      '  ${(r['title'] as String).padRight(30)} '
      '${r['kind'] == 0
          ? 'cover  '
          : r['kind'] == 1
          ? 'chapter'
          : 'lunii  '} '
      '${r['size']} ${r['aspect']}  '
      'prompt ${r['prompt_len']} chars  ${r['file_key']}',
    );
  }
  db.close();
}

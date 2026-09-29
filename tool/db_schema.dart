/// Read-only look at the on-disk app database — schema version, the shape of
/// the `beats` table, and whether any row has a null chapter title.
///
///     dart run tool/db_schema.dart
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  // sqlite3.dll ships with the built app, not with the Dart SDK — run this
  // with build\windows\x64\runner\Debug on PATH so the loader finds it.
  final path = args.isNotEmpty
      ? args.first
      : '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite';
  stdout.writeln('db: $path');

  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  stdout.writeln('user_version: ${db.select('pragma user_version').first}');

  stdout.writeln('\nbeats columns:');
  var hasChapterTitle = false;
  for (final row in db.select('pragma table_info(beats)')) {
    if (row['name'] == 'chapter_title') hasChapterTitle = true;
    stdout.writeln(
      '  ${row['name']}  type=${row['type']}  '
      'notnull=${row['notnull']}  default=${row['dflt_value']}',
    );
  }

  stdout.writeln(
    '\nrows: ${db.select('select count(*) c from beats').first['c']}',
  );
  if (hasChapterTitle) {
    final nulls = db
        .select('select count(*) c from beats where chapter_title is null')
        .first['c'];
    stdout.writeln('rows with NULL chapter_title: $nulls');
  } else {
    stdout.writeln(
      'chapter_title column is ABSENT — the migration did not run',
    );
  }
  db.close();
}

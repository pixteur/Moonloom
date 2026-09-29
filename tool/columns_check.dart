/// Confirms the columns every feature depends on are actually present in the
/// on-disk database, whatever version number it carries.
///
///     dart run tool/columns_check.dart
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);

  List<Object?> cols(String table) =>
      db.select('pragma table_info($table)').map((r) => r['name']).toList();

  final series = cols('series');
  final beats = cols('beats');
  final expected = {
    'series.last_read_seq': series.contains('last_read_seq'),
    'series.last_read_at': series.contains('last_read_at'),
    'beats.chapter_title': beats.contains('chapter_title'),
    'beats.narration_json': beats.contains('narration_json'),
  };

  stdout.writeln(
    'user_version: '
    '${db.select('pragma user_version').first['user_version']}',
  );
  for (final e in expected.entries) {
    stdout.writeln('${e.value ? "OK  " : "MISSING "} ${e.key}');
  }
  stdout.writeln(
    expected.values.every((v) => v) ? '\nall present' : '\nSOMETHING MISSING',
  );
  db.close();
}

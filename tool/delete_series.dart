/// Delete a story and its chapters. Run with the app closed.
///
///     dart run tool/delete_series.dart "Obsidian Stone Refined"
///     dart run tool/delete_series.dart --id 8fee31b1-0aa6-…
///     dart run tool/delete_series.dart --id <a> --id <b> --write
///
/// **Deleting by title matches every story with that title.** That is fine for
/// the case this was written for — dropping a refined copy — and wrong the
/// moment there is more than one story of the same name, which is exactly what
/// regenerating produces. So it lists what it would delete and stops, unless
/// `--write` is given; and `--id` names one story and no other.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final live = args.contains('--write');
  final ids = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--id' && i + 1 < args.length) ids.add(args[i + 1]);
  }
  final titles = args
      .where((a) => !a.startsWith('--'))
      .where((a) => !ids.contains(a))
      .toList();

  if (ids.isEmpty && titles.isEmpty) {
    stderr.writeln('Pass a story title, or --id <series id>.');
    exitCode = 2;
    return;
  }

  final db = sqlite3.open(
    '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite',
  );
  // Chapters hang off the series by foreign key; without this they'd be left
  // behind as orphans.
  db.execute('PRAGMA foreign_keys = ON');

  final doomed = <(String id, String title, int chapters)>[];
  void collect(String where, List<Object?> params) {
    for (final row in db.select(
      'select id, title from series where $where',
      params,
    )) {
      final id = row['id'] as String;
      final chapters =
          db.select('select count(*) c from beats where series_id = ?', [
                id,
              ]).first['c']
              as int;
      doomed.add((id, row['title'] as String, chapters));
    }
  }

  for (final id in ids) {
    collect('id = ?', [id]);
  }
  for (final title in titles) {
    collect('title = ?', [title]);
  }

  if (doomed.isEmpty) {
    stdout.writeln('Nothing matched.');
    db.close();
    return;
  }
  for (final (id, title, chapters) in doomed) {
    stdout.writeln('  "$title"  $chapters chapters  $id');
  }
  if (!live) {
    stdout.writeln(
      '\nDRY RUN — nothing deleted. Add --write to remove '
      '${doomed.length == 1 ? "it" : "these ${doomed.length}"}.',
    );
    db.close();
    return;
  }
  for (final (id, title, chapters) in doomed) {
    db.execute('delete from series where id = ?', [id]);
    stdout.writeln('Deleted "$title" ($id) and $chapters chapters.');
  }
  db.close();
}

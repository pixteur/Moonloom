/// Read-only: which stories exist for a child, and how much narration is
/// actually cached for the newest one. Used to pick a real story to export.
///
///     dart run tool/child_stories.dart [childName]
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final name = args.isNotEmpty ? args.first : 'Leila';
  final path =
      '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);

  final kids = db.select(
    'select id, display_name, language from child_profiles',
  );
  stdout.writeln('children: ${kids.map((r) => r['display_name']).join(', ')}');

  final child = kids.cast<Row?>().firstWhere(
    (r) => (r!['display_name'] as String).toLowerCase() == name.toLowerCase(),
    orElse: () => null,
  );
  if (child == null) {
    stdout.writeln('No child named "$name".');
    db.close();
    return;
  }
  stdout.writeln('\n$name (${child['id']}) language=${child['language']}');

  final stories = db.select(
    'select s.id, s.title, s.world_id, s.last_read_seq, s.updated_at, '
    '(select count(*) from beats b where b.series_id = s.id) chapters '
    'from series s where s.child_id = ? order by s.updated_at desc',
    [child['id']],
  );
  for (final s in stories) {
    stdout.writeln(
      '  ${s['title']}  chapters=${s['chapters']}  '
      'lastRead=${s['last_read_seq']}  id=${s['id']}',
    );
  }
  db.close();
}

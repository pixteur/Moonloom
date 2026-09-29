/// What narration direction actually got stored for a story's chapters.
///
///     dart run tool/cue_report.dart "Obsidian Stone Refined"
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final title = args.isNotEmpty ? args.first : 'Obsidian Stone Refined';
  final db = sqlite3.open(
    '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );
  final s = db.select('select id from series where title = ?', [title]);
  if (s.isEmpty) {
    stdout.writeln('No story titled "$title".');
    db.close();
    return;
  }
  final rows = db.select(
    'select seq, narration_json, story_text from beats '
    'where series_id = ? order by seq',
    [s.first['id']],
  );

  var withCues = 0;
  for (final r in rows) {
    final json = (r['narration_json'] as String?) ?? '';
    final paras = (r['story_text'] as String)
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length;
    final hasCues = json.contains('pace=') || json.contains('emotion=');
    if (hasCues) withCues++;
    stdout.writeln(
      'ch ${(r['seq'] as int) + 1}: $paras paragraphs, '
      '${json.length} bytes of direction${hasCues ? "" : "  (none)"}',
    );
  }
  stdout.writeln('\n$withCues of ${rows.length} chapters carry cues');
  if (rows.isNotEmpty) {
    stdout.writeln('\n─── chapter 1 direction ───');
    stdout.writeln(rows.first['narration_json']);
  }
  db.close();
}

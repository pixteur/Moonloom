/// Read-only comparison of a story against its refined copy.
///
///     dart run tool/refine_diff.dart "Obsidian Stone"
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

int _words(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

void main(List<String> args) {
  final title = args.isNotEmpty ? args.first : 'Obsidian Stone';
  final db = sqlite3.open(
    '${Platform.environment['USERPROFILE']}\\Documents\\moonloom.sqlite',
    mode: OpenMode.readOnly,
  );

  List<Map<String, Object?>> chaptersOf(String t) {
    final s = db.select('select id from series where title = ?', [t]);
    if (s.isEmpty) return const [];
    return db.select(
      'select seq, chapter_title, story_text, summary from beats '
      'where series_id = ? order by seq',
      [s.first['id']],
    );
  }

  final before = chaptersOf(title);
  final after = chaptersOf('$title Refined');
  stdout.writeln('"$title": ${before.length} chapters');
  stdout.writeln('"$title Refined": ${after.length} chapters\n');
  if (after.isEmpty) {
    db.close();
    return;
  }

  stdout.writeln('ch |  before |   after |  delta | chapter title');
  var totalBefore = 0, totalAfter = 0, changed = 0;
  for (var i = 0; i < before.length && i < after.length; i++) {
    final b = _words(before[i]['story_text'] as String);
    final a = _words(after[i]['story_text'] as String);
    totalBefore += b;
    totalAfter += a;
    if (before[i]['story_text'] != after[i]['story_text']) changed++;
    final pct = b == 0 ? 0 : ((a - b) / b * 100).round();
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)} | '
      '${b.toString().padLeft(7)} | ${a.toString().padLeft(7)} | '
      '${(pct >= 0 ? "+$pct%" : "$pct%").padLeft(6)} | '
      '${after[i]['chapter_title']}',
    );
  }
  stdout.writeln(
    '\ntotal $totalBefore -> $totalAfter words '
    '(${((totalAfter - totalBefore) / totalBefore * 100).toStringAsFixed(1)}%), '
    '$changed of ${before.length} chapters rewritten',
  );

  stdout.writeln('\n─── chapter 1, BEFORE ───');
  stdout.writeln((before.first['story_text'] as String).substring(0, 560));
  stdout.writeln('\n─── chapter 1, AFTER ───');
  stdout.writeln((after.first['story_text'] as String).substring(0, 560));

  // Paragraph count matters beyond style: the reader synthesizes one chunk
  // per paragraph, and narration cues are matched to paragraphs by index.
  int paras(String s) =>
      s.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;
  stdout.writeln('\nch | paragraphs before -> after');
  for (var i = 0; i < before.length && i < after.length; i++) {
    final b = paras(before[i]['story_text'] as String);
    final a = paras(after[i]['story_text'] as String);
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)} | $b -> $a${b == a ? "" : "   CHANGED"}',
    );
  }

  // Things the brief explicitly bans in read-aloud text.
  for (final entry in {'em dash': '—', 'semicolon': ';'}.entries) {
    final b = before.fold(
      0,
      (n, r) => n + entry.value.allMatches(r['story_text'] as String).length,
    );
    final a = after.fold(
      0,
      (n, r) => n + entry.value.allMatches(r['story_text'] as String).length,
    );
    stdout.writeln('\n${entry.key}s: $b -> $a');
  }
  db.close();
}

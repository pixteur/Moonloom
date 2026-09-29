/// Paragraph-by-paragraph breakdown of one chapter — the unit the reader
/// synthesizes and the unit narration cues attach to.
///
/// Roughly 150 words a minute is an unhurried bedtime read, so a paragraph
/// under ~3 seconds is a chunk the voice barely gets moving on before it stops.
///
///     dart run tool/chunk_report.dart "Obsidian Stone Refined" 1
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _wordsPerSecond = 150 / 60;

void main(List<String> args) {
  final title = args.isNotEmpty ? args.first : 'Obsidian Stone Refined';
  final seq = args.length > 1 ? int.parse(args[1]) - 1 : 0;

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
    'select story_text from beats where series_id = ? and seq = ?',
    [s.first['id'], seq],
  );
  if (rows.isEmpty) {
    stdout.writeln('No chapter ${seq + 1}.');
    db.close();
    return;
  }

  final paras = (rows.first['story_text'] as String)
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  stdout.writeln('"$title" chapter ${seq + 1}: ${paras.length} paragraphs\n');
  stdout.writeln(' # | words |  ~secs | opening');
  var short = 0;
  for (var i = 0; i < paras.length; i++) {
    final w = paras[i].split(RegExp(r'\s+')).length;
    final secs = w / _wordsPerSecond;
    if (secs < 3) short++;
    final head = paras[i].length > 46 ? paras[i].substring(0, 46) : paras[i];
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)} | ${w.toString().padLeft(5)} | '
      '${secs.toStringAsFixed(1).padLeft(6)} | $head',
    );
  }
  final total = paras.fold(0, (n, p) => n + p.split(RegExp(r'\s+')).length);
  stdout.writeln(
    '\n$total words, ${(total / _wordsPerSecond / 60).toStringAsFixed(1)} min, '
    '${paras.length} synthesis requests, '
    '$short of ${paras.length} under 3 seconds',
  );
  db.close();
}

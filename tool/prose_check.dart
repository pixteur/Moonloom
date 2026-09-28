/// Read-only: look at the prose the app has actually saved and count the
/// things that only show up on a real chapter.
///
/// Written after a smoke test came back with dialogue but no quotation marks —
/// "we should go, whispered Pip". The rule that keeps markup out of a chapter
/// (because a voice reads markup aloud) may be taking punctuation with it, and
/// the only way to know is to read what is in the library rather than what the
/// prompt asks for.
///
///     dart run tool/prose_check.dart [--db path]
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final at = args.indexOf('--db');
  final path = at >= 0 && at + 1 < args.length
      ? args[at + 1]
      : '${Platform.environment['USERPROFILE']}\\Documents\\sleepytime.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);

  final rows = db.select(
    'select b.chapter_title as title, b.story_text, s.title as story '
    'from beats b join series s on s.id = b.series_id '
    'order by b.created_at desc',
  );

  var withSpeech = 0;
  var quoted = 0;
  var placeholderTitle = 0;
  var markup = 0;
  final samples = <String>[];
  final strays = <String>[];

  for (final r in rows) {
    final text = (r['story_text'] as String?) ?? '';
    final title = (r['title'] as String?) ?? '';
    // A reporting verb is the shape of spoken dialogue, with or without the
    // quotation marks this is looking for — so match the verb alone, or a
    // chapter that quotes gets counted as having no dialogue at all.
    final speaks = RegExp(
      r'\b(said|says|whispered|asked|replied|called|murmured)\b',
      caseSensitive: false,
    ).hasMatch(text);
    if (speaks) {
      withSpeech++;
      if (text.contains('"') || text.contains('“') || text.contains('«')) {
        quoted++;
      } else if (samples.length < 4) {
        final m = RegExp(
          r'[^.!?]*,\s*(said|whispered|asked|replied)\b[^.!?]*',
          caseSensitive: false,
        ).firstMatch(text);
        if (m != null) samples.add('${r['story']} — ${m.group(0)!.trim()}');
      }
    }
    if (RegExp(
      r'^\s*(chapter|chapitre)\s',
      caseSensitive: false,
    ).hasMatch(title)) {
      placeholderTitle++;
    }
    final stray = RegExp(r'[*_`\[\]]').allMatches(text);
    if (stray.isNotEmpty) {
      markup++;
      final around = RegExp(r'.{0,30}[*_`\[\]].{0,30}').firstMatch(text);
      if (around != null) {
        strays.add('${r['story']} — …${around.group(0)!.trim()}…');
      }
    }
  }

  stdout.writeln('chapters: ${rows.length}');
  stdout.writeln('  with spoken dialogue:      $withSpeech');
  stdout.writeln('  of those, using quotes:    $quoted');
  stdout.writeln('  numbered chapter titles:   $placeholderTitle');
  stdout.writeln('  containing stray markup:   $markup');
  if (samples.isNotEmpty) {
    stdout.writeln('\nunquoted speech, as saved:');
    for (final s in samples) {
      stdout.writeln('  $s');
    }
  }
  if (strays.isNotEmpty) {
    stdout.writeln('\nmarkup a voice would read out loud:');
    for (final s in strays) {
      stdout.writeln('  $s');
    }
  }
  db.close();
}

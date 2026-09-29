/// Read-only: is the same character the same creature in every story?
///
/// A world's cast is the thing a child recognises. If Pip is a fox in one
/// episode and a penguin in the next, the world is not a place, it is a name
/// on a folder. This looks at what each story actually says about a character
/// — the first sentence that introduces them — so the drift can be seen rather
/// than argued about.
///
///     dart run tool/character_drift.dart [--child Mia] [--who Pip]
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Words that would tell you what something IS. Deliberately broad: the point
/// is to surface every claim about the character, not to judge them.
final _species = RegExp(
  r'\b(fox|cat|dog|puppy|kitten|rabbit|bunny|bear|owl|mouse|mice|otter|'
  r'turtle|tortoise|penguin|seal|whale|dolphin|fish|crab|gull|bird|badger|'
  r'hedgehog|squirrel|deer|wolf|robot|dragon|boy|girl|child|man|woman|'
  r'lantern|star|cloud|sprite|fairy|snail|frog|toad|hare|pup|cub)\b',
  caseSensitive: false,
);

String? _opt(List<String> a, String n) {
  final at = a.indexOf(n);
  return at >= 0 && at + 1 < a.length ? a[at + 1] : null;
}

void main(List<String> args) {
  final path =
      r''
      '${Platform.environment['USERPROFILE']}'
      r'\Documents\moonloom.sqlite';
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  final childName = _opt(args, '--child') ?? 'Mia';
  final who = _opt(args, '--who') ?? 'Pip';

  final kid = db
      .select('select id, display_name from child_profiles')
      .cast<Row?>()
      .firstWhere(
        (r) =>
            (r!['display_name'] as String).toLowerCase() ==
            childName.toLowerCase(),
        orElse: () => null,
      );
  if (kid == null) {
    stdout.writeln('No child called $childName.');
    db.close();
    return;
  }

  stdout.writeln('What each story says $who is\n');
  final rows = db.select(
    'select s.id, s.title, s.world_id from series s where s.child_id = ? '
    'order by s.created_at',
    [kid['id']],
  );

  for (final s in rows) {
    final beats = db.select(
      'select seq, story_text, characters from beats where series_id = ? '
      'order by seq',
      [s['id']],
    );
    final claims = <String>{};
    for (final b in beats) {
      final text = (b['story_text'] as String?) ?? '';
      // The sentence that first puts a word near the name is the one that
      // introduces them; later mentions assume you already know.
      for (final sentence in text.split(RegExp(r'(?<=[.!?])\s+'))) {
        if (!sentence.toLowerCase().contains(who.toLowerCase())) continue;
        for (final m in _species.allMatches(sentence)) {
          claims.add(m.group(0)!.toLowerCase());
        }
      }
      final listed = (b['characters'] as String?) ?? '';
      for (final m in _species.allMatches(listed)) {
        if (listed.toLowerCase().contains(who.toLowerCase())) {
          claims.add('[cast] ${m.group(0)!.toLowerCase()}');
        }
      }
    }
    if (claims.isEmpty) continue;
    stdout.writeln(
      '  ${(s['title'] as String).padRight(30)} '
      '${s['world_id'] == null ? '(no world)' : ''} ${claims.join(', ')}',
    );
  }

  stdout.writeln('\nSaved cast, by world:');
  for (final w in db.select('select id, name from worlds where child_id = ?', [
    kid['id'],
  ])) {
    final cast = db.select(
      'select name, description from characters where world_id = ?',
      [w['id']],
    );
    stdout.writeln('  ${w['name']}');
    if (cast.isEmpty) stdout.writeln('    (nobody saved)');
    for (final c in cast) {
      stdout.writeln('    ${c['name']}: ${c['description']}');
    }
  }
  db.close();
}

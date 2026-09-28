/// Last line of defence for anything a voice will read aloud.
///
/// The prompt tells the model twice that a chapter is spoken, so markup must
/// not appear in it — and the model mostly listens. Mostly is not enough. Four
/// chapters in the real library carry an asterisk pair, and every one of them
/// is the same case the prompt already warned about: a foreign word the model
/// wanted to emphasise. `*brillant*`, `*petit nœud*`, `*hoshi*`. A child
/// hearing those gets "asterisk brillant asterisk" in the middle of a bedtime
/// story, and a bilingual story — the one feature most likely to provoke it —
/// is exactly where it hurts most.
///
/// Same shape as the chapter floor and the title guard: asking produced the
/// right answer nearly always, and the ones it missed had to be fixed in code.
/// So this runs over every chapter before it is saved. See
/// `docs/narration-cues.md` for why direction never travels inside the text.
library;

/// Emphasis wrapped around a word or short phrase: `*brillant*`, `_soft_`.
/// The delimiters go and the word stays — the model meant the word.
final RegExp _emphasis = RegExp(
  r'(?<![\w*_])([*_])(?!\s)([^*_\n]{1,80})(?<!\s)\1(?![\w*_])',
);

/// A bracketed aside: `[whispers]`, `[in French]`. Unlike emphasis there is no
/// word worth keeping — these are directions to the reader, and direction
/// belongs in a NarrationCue, never in the prose.
final RegExp _bracketed = RegExp(r'\s*\[[^\]\n]{0,80}\]');

/// Anything left over: a lone asterisk, a backtick, a stray bracket. By this
/// point it is unpaired and meaningless, and it would still be spoken.
final RegExp _leftovers = RegExp(r'[*`\[\]]');

/// Collapse the whitespace a removal can leave behind, without touching the
/// blank line that separates paragraphs — chunking reads those.
final RegExp _runsOfSpace = RegExp(r'[ \t]{2,}');

/// Only the comma and the full stop. French puts a space before ? ! ; and :
/// — «arrivés ?» is correct typography there, and a bilingual story is the
/// main place this runs, so touching those would quietly restyle the French.
final RegExp _spaceBeforePunctuation = RegExp(r' +([,.])');

/// The chapter as it should be spoken and shown.
///
/// Pure and idempotent: running it twice changes nothing, so it is safe to
/// apply on save and again on anything older that was stored before it
/// existed. Accents, quotation marks and parentheses are left alone — they are
/// punctuation a voice reads correctly, not formatting.
String stripSpokenMarkup(String text) {
  if (text.isEmpty) return text;
  var out = text;
  // Twice: `**very**` unwraps one layer at a time.
  for (var i = 0; i < 2; i++) {
    out = out.replaceAllMapped(_emphasis, (m) => m.group(2)!);
  }
  return out
      .replaceAll(_bracketed, '')
      .replaceAll(_leftovers, '')
      .replaceAll(_runsOfSpace, ' ')
      .replaceAllMapped(_spaceBeforePunctuation, (m) => m.group(1)!)
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .trim();
}

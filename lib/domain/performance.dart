/// Turning a chapter's paragraphs into a performance: who says each stretch of
/// it, and how.
///
/// Gemini 3.8 TTS takes a request as a list of parts, each with its own
/// speaker and its own delivery (`speech_metadata.style`), rendered as one
/// continuous recording. That is the shape a bedtime reading wants:
///
///   * **the narrator** reads everything that is not dialogue, in the
///     chapter's voice, coloured paragraph by paragraph by the editorial
///     pass's cues;
///   * **the hero**, when the story's hero has a voice of their own, speaks
///     their own lines in it;
///   * **everyone else** is played by the narrator, changing tone the way a
///     parent does at the bedside — "slow and gruff, as Barnaby the crab" —
///     rather than by a cast of strangers. Gemini allows two voices per
///     request, and narrator-plus-hero is the pair that matters.
///
/// The child is never given a voice. When the child is the hero, the narrator
/// reads their lines: designing a child's voice is refused by the voice
/// service, and an app for children has no business synthesising one.
///
/// Pure Dart and exact: joining every part's text gives back the chunk's text
/// character for character. The words on screen are therefore always the words
/// spoken — the property every other rule here exists to protect.
library;

import 'cast_line.dart';
import 'models/narration.dart';

/// Who voices a part.
enum PartVoice { narrator, hero }

/// One stretch of a chapter and how to deliver it.
class SpeechPart {
  const SpeechPart(this.text, this.voice, this.style);

  final String text;
  final PartVoice voice;

  /// Delivery for this part alone, in plain words. Never markup: it travels in
  /// its own field, and the voice never reads it.
  final String style;

  @override
  String toString() => '[${voice.name}|$style] $text';
}

/// Quote marks that open dialogue, and the mark that closes each. A straight
/// double quote both opens and closes.
const _openers = {'"': '"', '“': '”', '«': '»'};

/// The paragraphs of [text] as performed parts.
///
/// [cues] and [speakers] are per paragraph of [text], in order, as the
/// editorial pass wrote them; [speakers] entries list who speaks each quoted
/// line of that paragraph, in order ("Pip, Barnaby"). A paragraph whose
/// speaker count does not match its quote count has every line read by the
/// narrator in the paragraph's own delivery — a misattributed line in the
/// wrong voice is worse than an unacted one.
///
/// [heroName] is whoever has a voice of their own, or null when nobody does.
/// [characterVoices] are the editorial pass's "Name — how they sound" lines,
/// used as the narrator's acting direction.
List<SpeechPart> performParagraphs(
  String text, {
  List<NarrationCue> cues = const [],
  List<String> speakers = const [],
  List<String> characterVoices = const [],
  String standingStyle = '',
  String? heroName,
}) {
  final acting = {
    for (final line in characterVoices)
      if (parseCastEntry(line).$1.isNotEmpty)
        foldedName(parseCastEntry(line).$1): (
          parseCastEntry(line).$1,
          parseCastEntry(line).$2,
        ),
  };
  final hero = heroName == null || heroName.trim().isEmpty
      ? null
      : foldedName(heroName);

  // Split on the paragraph breaks but keep them, so the parts join back into
  // exactly the text that came in.
  final pieces = text.split(RegExp(r'(\n\s*\n)'));
  final breaks = RegExp(r'\n\s*\n').allMatches(text).map((m) => m[0]!).toList();

  final out = <SpeechPart>[];
  void add(String t, PartVoice v, String s) {
    if (t.isEmpty) return;
    if (out.isNotEmpty && out.last.voice == v && out.last.style == s) {
      out[out.length - 1] = SpeechPart(out.last.text + t, v, s);
    } else {
      out.add(SpeechPart(t, v, s));
    }
  }

  for (var p = 0; p < pieces.length; p++) {
    final paragraph = pieces[p];
    final cue = p < cues.length ? cues[p] : const NarrationCue();
    final narration = _join(standingStyle, cue.asDirection());
    final names = p < speakers.length
        ? speakers[p]
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : const <String>[];

    final runs = _runs(paragraph);
    final quoteCount = runs.where((r) => r.$2).length;
    final attributed = names.length == quoteCount;

    var quote = 0;
    for (final (run, isQuote) in runs) {
      if (!isQuote) {
        add(run, PartVoice.narrator, narration);
        continue;
      }
      final who = attributed ? names[quote] : null;
      quote++;
      final key = who == null ? null : foldedName(who);
      if (key != null && key == hero) {
        // The hero speaks for themselves; the cue says how they feel.
        add(run, PartVoice.hero, cue.asDirection());
      } else if (key != null && acting.containsKey(key)) {
        final (name, how) = acting[key]!;
        add(
          run,
          PartVoice.narrator,
          _join(
            how.isEmpty ? 'voicing $name' : 'voicing $name: $how',
            cue.asDirection(),
          ),
        );
      } else {
        add(run, PartVoice.narrator, narration);
      }
    }
    if (p < breaks.length) {
      // The break belongs to whatever came before it, so it never starts a
      // part of its own — a part of pure whitespace is a request for silence.
      if (out.isEmpty) {
        add(breaks[p], PartVoice.narrator, narration);
      } else {
        out[out.length - 1] = SpeechPart(
          out.last.text + breaks[p],
          out.last.voice,
          out.last.style,
        );
      }
    }
  }
  return out;
}

/// A paragraph as alternating narration and quoted runs, quote marks kept on
/// the quoted run. An unclosed quote runs to the end of the paragraph, which
/// is what a reader would assume too.
List<(String, bool)> _runs(String paragraph) {
  final out = <(String, bool)>[];
  final buffer = StringBuffer();
  String? closer;
  for (final ch in paragraph.split('')) {
    if (closer == null && _openers.containsKey(ch)) {
      if (buffer.isNotEmpty) out.add((buffer.toString(), false));
      buffer
        ..clear()
        ..write(ch);
      closer = _openers[ch];
    } else if (closer != null && ch == closer) {
      buffer.write(ch);
      out.add((buffer.toString(), true));
      buffer.clear();
      closer = null;
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) out.add((buffer.toString(), closer != null));
  return out;
}

String _join(String a, String b) => a.isEmpty
    ? b
    : b.isEmpty
    ? a
    : '$a. $b';

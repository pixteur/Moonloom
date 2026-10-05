/// Splitting a chapter into synthesis chunks that respect narration direction.
///
/// Two forces pull opposite ways. The reader deliberately uses **a few sizeable
/// chunks** so each one's playback outlasts the next one's synthesis, which is
/// what hides a cloud voice's fixed per-request latency. But a narration cue
/// applies to a paragraph, and a cue can only be honoured if it maps onto a
/// whole request — you cannot change the voice halfway through one.
///
/// The hybrid rule: **a chunk boundary is forced only where the direction
/// actually changes.** Consecutive paragraphs sharing a cue are merged and then
/// handed to the ordinary size-based chunker, so a chapter narrated in one
/// voice throughout costs exactly what it costs today. Only a chapter that
/// genuinely shifts tone pays for the extra requests, and only at the points
/// where it shifts.
library;

import '../../domain/models/narration.dart';
import '../../domain/performance.dart';
import 'audio_cache_key.dart';

/// One synthesis request: the text to speak and the direction to speak it in.
class NarratedChunk {
  const NarratedChunk(
    this.text,
    this.cue, {
    this.paragraphCues,
    this.speakers = const [],
  });

  final String text;
  final NarrationCue cue;

  /// Each paragraph of this chunk's own cue, in order — or null when the chunk
  /// does not line up with whole paragraphs, which happens only to a chapter
  /// long enough to be split mid-paragraph. A voice that can change delivery
  /// part by part uses these; without them it reads the chunk in one voice.
  final List<NarrationCue>? paragraphCues;

  /// Each paragraph of this chunk's speakers, as the editorial pass wrote
  /// them: who says each quoted line, comma separated.
  final List<String> speakers;

  /// Mixed into the audio-cache key. The cue changes the audio without
  /// changing a word of the text, so a key built from the text alone would
  /// replay the previous reading — and so do the speakers, once there are
  /// any, because they decide whose voice a line is read in.
  ///
  /// Only once there are any. Every chapter recorded before speakers existed
  /// keeps exactly the key it was saved under; a change that moved them all
  /// would make a library of narration look deleted, which is the trap in
  /// CLAUDE.md about changing voice.
  String get cacheSuffix {
    final direction = cue.isEmpty ? '' : '|${cue.encode()}';
    final voices = speakers.any((s) => s.trim().isNotEmpty)
        ? '|speakers=${speakers.join('/')}'
        : '';
    return '$direction$voices';
  }

  @override
  String toString() => '${text.length} chars ${cue.isEmpty ? "-" : cue}';
}

/// Build the chunks for [text] under [notes].
///
/// [sizeChunker] is the reader's existing size-based splitter, applied within
/// each run of same-direction paragraphs.
List<NarratedChunk> narratedChunks(
  String text,
  NarrationNotes notes,
  List<String> Function(String) sizeChunker,
) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (paragraphs.isEmpty) return const [];

  // Who says each quoted line, found by its words rather than its position:
  // a miscounted list then loses a line to the narrator instead of shifting
  // every later line onto the wrong character. See `attributeQuotes`.
  final perParagraph = notes.speakers.isEmpty
      ? const <String>[]
      : attributeQuotes(paragraphs, notes.speakers);
  String speakerAt(int i) =>
      i >= 0 && i < perParagraph.length ? perParagraph[i] : '';

  // With no direction at all, this must behave exactly like the reader does
  // today — same chunks, same cache keys, same request count.
  if (notes.cues.every((c) => c.isEmpty)) {
    final pieces = sizeChunker(text);
    final aligned = pieces.length == 1;
    return [
      for (final chunk in pieces)
        NarratedChunk(
          chunk,
          notes.cueAt(-1),
          paragraphCues: aligned
              ? [for (var j = 0; j < paragraphs.length; j++) notes.cueAt(-1)]
              : null,
          speakers: aligned
              ? [for (var j = 0; j < paragraphs.length; j++) speakerAt(j)]
              : const [],
        ),
    ];
  }

  final out = <NarratedChunk>[];
  var runStart = 0;
  for (var i = 1; i <= paragraphs.length; i++) {
    // Split on a change of FEELING only, not on any difference at all.
    //
    // Every boundary is a separate request, and a voice model re-derives its
    // delivery per request — so chunks carrying different instructions come
    // back at different timbres and levels, and a chapter split five ways is
    // audibly read by five slightly different narrators. Pace and phrasing
    // notes still travel with their group; they just stop cutting the audio.
    final endOfRun =
        i == paragraphs.length ||
        notes.cueAt(i).emotion != notes.cueAt(runStart).emotion;
    if (!endOfRun) continue;
    final run = paragraphs.sublist(runStart, i).join('\n\n');
    final pieces = sizeChunker(run);
    // A run that fits one request lines up with its paragraphs exactly; one
    // split by size does not, and is read in one voice rather than risk
    // giving a line to the wrong paragraph's speaker.
    final aligned = pieces.length == 1;
    for (final chunk in pieces) {
      out.add(
        NarratedChunk(
          chunk,
          notes.cueAt(runStart),
          paragraphCues: aligned
              ? [for (var j = runStart; j < i; j++) notes.cueAt(j)]
              : null,
          speakers: aligned
              ? [for (var j = runStart; j < i; j++) speakerAt(j)]
              : const [],
        ),
      );
    }
    runStart = i;
  }
  return out;
}

/// Synthesize a whole chapter as ONE request when possible: a single request
/// gives a consistent voice (volume/prosody drift between separate Gemini TTS
/// calls is what made paragraphs sound like "a different reader"), removes
/// inter-paragraph seams entirely, and makes far fewer API calls (one per
/// chapter, not per paragraph) — so rate limits are hit far less often.
///
/// Only a very long chapter is split, and then only on sentence boundaries
/// into large pieces, to stay within the provider's per-request limit.
///
/// Lives here rather than inside the provider because it is half of what
/// decides a cache key, and [chapterAudioKeys] has to agree with playback
/// exactly.
List<String> sizeChunks(String text, {int maxLen = 6000}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.length <= maxLen) return [trimmed];

  final sentences = trimmed
      .replaceAll(RegExp(r'\n\s*\n'), ' ')
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  final out = <String>[];
  final buf = StringBuffer();
  for (final s in sentences) {
    if (buf.isNotEmpty && buf.length + s.length > maxLen) {
      out.add(buf.toString().trim());
      buf.clear();
    }
    buf.write('$s ');
  }
  if (buf.isNotEmpty) out.add(buf.toString().trim());
  return out.isEmpty ? [trimmed] : out;
}

/// **The** mapping from a chapter to the audio-cache entries that hold its
/// narration, in playback order.
///
/// One home for this on purpose. Playback writes a key per chunk with the
/// chunk's cue mixed in; anything that later goes looking for a chapter's audio
/// — the download badge, the `.sleepy`, audiobook, and Lunii exports — has to
/// ask the same question the same way. When these drifted apart, fully
/// downloaded stories exported as "no narration saved yet", and only chapters
/// written before narration cues existed still worked. See
/// `docs/lunii-export.md` and `tool/export_keys_check.dart`.
List<String> chapterAudioKeys({
  required String voiceSignature,
  required String language,
  required String text,
  NarrationNotes notes = const NarrationNotes(),
}) => [
  for (final chunk in narratedChunks(text, notes, sizeChunks))
    chunkAudioKey(
      voiceSignature: voiceSignature,
      language: language,
      chunk: chunk,
    ),
];

/// The cache key for one chunk.
///
/// The single expression every key is built from, so that "ask
/// [chapterAudioKeys]" and "look one chunk up during playback" cannot drift
/// into asking different questions. They had drifted once already — exports
/// keyed on a whole chapter's text, and fully downloaded stories reported no
/// narration saved. The cue is in the key because it changes the audio without
/// changing a word of the text.
String chunkAudioKey({
  required String voiceSignature,
  required String language,
  required NarratedChunk chunk,
}) => audioCacheKey(
  '$voiceSignature|$language|${chunk.text}${chunk.cacheSuffix}',
);

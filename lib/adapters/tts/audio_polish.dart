/// Evening out a cloud voice's level, and giving a paragraph its pause back.
///
/// Two things were wrong with the Gemini narration, and `tool/audio_shape.dart`
/// measured both on a real 201-second chunk rather than leaving them a matter
/// of taste:
///
///   * **The level drifts.** Loudness ranged over **18.8 dB** inside a single
///     request, climbing steadily from start to end. This is not the seam
///     between chunks — it is one utterance getting louder as it goes, so no
///     amount of chunking differently would fix it.
///   * **A paragraph break sounds like a sentence break.** The pauses are
///     there, but at 500–760 ms against 160–260 ms for a sentence, they are
///     not different enough to hear as a new paragraph.
///
/// Both are answerable in the waveform, which matters: re-synthesising a
/// library costs money and a prompt change cannot be applied to audio already
/// paid for. This runs on the PCM we already hold.
///
/// **What it deliberately does not do.** It never normalises a chunk to a
/// fixed absolute level. A cue asking for a hushed passage is meant to be
/// quieter than the chapter around it, and cue changes force chunk boundaries,
/// so flattening every chunk to one target would erase exactly the direction
/// the editorial pass worked to produce. The target is each chunk's own
/// median, so drift within a chunk is corrected and the difference between
/// chunks is left alone. See `docs/narration-cues.md`.
library;

import 'dart:math';
import 'dart:typed_data';

/// A run of speech, and the silence that follows it.
class _Segment {
  _Segment(this.start, this.end);

  /// Sample indices into the PCM body, not byte offsets.
  final int start;
  int end;
  double rms = 0;
  double gain = 1;
}

/// Anything below this is silence rather than quiet speech.
const double _silenceFloor = -50;

/// Shorter than this is a breath inside a sentence, not a break between them.
const int _minGapMs = 150;

/// A gap at least this long is a paragraph or a strong beat, and is the kind
/// worth lengthening. Sentence pauses measured 160–260 ms, paragraph pauses
/// 500–760 ms, so the line sits above the first cluster and below the second.
const int _paragraphGapMs = 420;

/// What a paragraph break should actually last. Long enough to hear as a new
/// paragraph, short enough that a child does not think the story stopped.
const int _targetParagraphGapMs = 900;

/// The most the slow drift correction may move the level. Enough to cancel
/// the 4–5 dB climb measured across a chunk, small enough that it can never
/// be mistaken for a compressor.
const double _maxDriftDb = 4;

/// Polish one chunk of narration.
///
/// Takes and returns a 16-bit PCM WAV. Anything else — an MP3 from ElevenLabs
/// or OpenAI — is returned untouched, because the sample data is not ours to
/// read without decoding it first.
Uint8List polishNarration(Uint8List wav) {
  if (!_isPcmWav(wav)) return wav;
  final view = ByteData.sublistView(wav);
  final rate = view.getUint32(24, Endian.little);
  final channels = max(1, view.getUint16(22, Endian.little));
  if (rate == 0) return wav;

  final count = (wav.length - 44) ~/ 2;
  if (count == 0) return wav;
  final samples = Int16List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = view.getInt16(44 + i * 2, Endian.little);
  }

  final perChannel = rate * channels;
  final segments = _findSegments(samples, perChannel);
  // One unbroken run of speech has no seams to even out and no breaks to
  // lengthen; leave it exactly as the model sang it.
  if (segments.length < 2) return wav;

  final gain = _driftGain(samples, perChannel);
  final out = _rebuild(samples, segments, gain, perChannel);
  return _wrap(out, wav);
}

bool _isPcmWav(Uint8List b) =>
    b.length > 44 &&
    b[0] == 0x52 &&
    b[1] == 0x49 &&
    b[2] == 0x46 &&
    b[3] == 0x46 &&
    ByteData.sublistView(b).getUint16(34, Endian.little) == 16;

/// Split into runs of speech separated by silences of at least [_minGapMs].
List<_Segment> _findSegments(Int16List s, int perSecond) {
  final window = max(1, perSecond ~/ 50); // 20 ms
  final minGap = perSecond * _minGapMs ~/ 1000;
  final segments = <_Segment>[];
  _Segment? open;
  var quietFrom = -1;

  for (var i = 0; i + window <= s.length; i += window) {
    final quiet = _dbfs(s, i, i + window) < _silenceFloor;
    if (quiet) {
      if (quietFrom < 0) quietFrom = i;
      continue;
    }
    if (quietFrom >= 0 && open != null && i - quietFrom >= minGap) {
      open.end = quietFrom;
      segments.add(open);
      open = null;
    }
    quietFrom = -1;
    open ??= _Segment(i, i);
  }
  if (open != null) {
    open.end = s.length;
    segments.add(open);
  }
  return segments;
}

/// Flatten the slow drift across a chunk, and nothing faster than that.
///
/// The first attempt here normalised every segment to the chunk's median, and
/// `tool/polish_cache.dart` measured it doing essentially nothing — 31,9 dB of
/// spread became 31,1 dB. The reason is that a segment boundary is any 150 ms
/// gap, so segments are *sentences*, and sentences are supposed to differ:
/// a short exclamation is louder than a trailing clause, and levelling them
/// together would iron the life out of the reading without touching the fault.
///
/// The fault measured on real output is slower than that — loudness climbing
/// steadily from the start of a request to its end, about 4 to 5 dB over three
/// minutes. So this fits a gain curve over a long window, which cancels the
/// trend and leaves every sentence's own shape intact.
List<double> _driftGain(Int16List s, int perSecond) {
  // Eight seconds: far longer than a sentence, far shorter than a chunk.
  final window = perSecond * 8;
  final bands = <double>[];
  for (var i = 0; i < s.length; i += window) {
    // Speech only. Including the silences would make a passage with long
    // pauses look quiet and have the gain chase the pauses, not the voice.
    final loud = _speechRms(s, i, min(i + window, s.length));
    bands.add(loud);
  }
  if (bands.length < 3) return const [];

  // A moving average over three bands, so the correction cannot follow
  // anything abrupt enough to be heard as pumping.
  final smooth = <double>[
    for (var i = 0; i < bands.length; i++)
      [
            bands[max(0, i - 1)],
            bands[i],
            bands[min(bands.length - 1, i + 1)],
          ].where((v) => v > 0).fold(0.0, (a, b) => a + b) /
          max(
            1,
            [
              bands[max(0, i - 1)],
              bands[i],
              bands[min(bands.length - 1, i + 1)],
            ].where((v) => v > 0).length,
          ),
  ];

  final present = smooth.where((v) => v > 0).toList()..sort();
  if (present.isEmpty) return const [];
  final target = present[present.length ~/ 2];

  final ceiling = pow(10, _maxDriftDb / 20).toDouble();
  return [
    for (final band in smooth)
      band <= 0 ? 1.0 : (target / band).clamp(1 / ceiling, ceiling),
  ];
}

/// RMS of the parts of a span that are actually speech.
double _speechRms(Int16List s, int from, int to) {
  final step = max(1, (to - from) ~/ 400);
  var sum = 0.0;
  var n = 0;
  for (var i = from; i + step <= to; i += step) {
    final r = _linearRms(s, i, i + step);
    if (r > 0.003) {
      // above about -50 dBFS
      sum += r * r;
      n++;
    }
  }
  return n == 0 ? 0 : sqrt(sum / n);
}

/// Apply the drift gain and stretch the paragraph gaps, writing a fresh body.
Uint8List _rebuild(
  Int16List s,
  List<_Segment> segments,
  List<double> gain,
  int perSecond,
) {
  final paragraphGap = perSecond * _paragraphGapMs ~/ 1000;
  final targetGap = perSecond * _targetParagraphGapMs ~/ 1000;
  final band = perSecond * 8;
  final out = <int>[];

  /// The gain at one sample, interpolated between band centres so it moves
  /// continuously rather than in steps.
  double gainAt(int i) {
    if (gain.isEmpty) return 1;
    final pos = (i / band) - 0.5;
    final lo = pos.floor().clamp(0, gain.length - 1);
    final hi = (lo + 1).clamp(0, gain.length - 1);
    final t = (pos - lo).clamp(0.0, 1.0);
    return gain[lo] + (gain[hi] - gain[lo]) * t;
  }

  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    for (var j = seg.start; j < seg.end && j < s.length; j++) {
      out.add((s[j] * gainAt(j)).round().clamp(-32768, 32767));
    }

    if (i == segments.length - 1) break;
    // The silence between this segment and the next: keep it, and lengthen it
    // when it is long enough to be a paragraph rather than a sentence.
    final gap = segments[i + 1].start - seg.end;
    final keep = gap >= paragraphGap ? max(gap, targetGap) : gap;
    for (var j = 0; j < keep; j++) {
      out.add(
        j < gap
            ? (s[min(seg.end + j, s.length - 1)] * gainAt(seg.end + j))
                  .round()
                  .clamp(-32768, 32767)
            : 0,
      );
    }
  }

  // Keep whatever trailed the last segment, so a chapter does not end abruptly.
  for (var j = segments.last.end; j < s.length; j++) {
    out.add((s[j] * gainAt(j)).round().clamp(-32768, 32767));
  }
  return Uint8List.fromList(out.expand(_le16).toList());
}

Iterable<int> _le16(int sample) sync* {
  final v = sample & 0xFFFF;
  yield v & 0xFF;
  yield (v >> 8) & 0xFF;
}

/// A new WAV carrying [body], with the original's format fields and corrected
/// sizes. Written by hand rather than patched in place because the body has
/// changed length and two header fields describe that.
Uint8List _wrap(Uint8List body, Uint8List original) {
  final out = Uint8List(44 + body.length);
  out.setRange(0, 44, original);
  final view = ByteData.sublistView(out);
  view.setUint32(4, 36 + body.length, Endian.little);
  view.setUint32(40, body.length, Endian.little);
  out.setRange(44, 44 + body.length, body);
  return out;
}

double _linearRms(Int16List s, int from, int to) {
  var sum = 0.0;
  final end = min(to, s.length);
  for (var i = from; i < end; i++) {
    final v = s[i] / 32768.0;
    sum += v * v;
  }
  final n = end - from;
  return n <= 0 ? 0 : sqrt(sum / n);
}

double _dbfs(Int16List s, int from, int to) {
  final rms = _linearRms(s, from, to);
  return rms <= 1e-6 ? -120 : 20 * (log(rms) / ln10);
}

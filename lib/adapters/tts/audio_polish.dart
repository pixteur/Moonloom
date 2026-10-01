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

  // The model's own clicks, before anything else is done.
  //
  // Measured on the real cache: twenty Gemini chapters carry forty-six steps
  // where the waveform jumps thousands of units between two adjacent samples,
  // next to silence. That is not drift and not a splice — it is in the audio
  // as the model returned it, and it is what is heard as a pop of static at
  // the end of a paragraph. The level correction cannot help; it multiplies
  // them along with everything else, which is why the first attempt at this
  // made the complaint worse rather than better.
  _deClick(samples, perChannel);

  final segments = _findSegments(samples, perChannel);
  // One unbroken run of speech has no seams to even out and no breaks to
  // lengthen; leave it exactly as the model sang it — but it has still been
  // de-clicked above, because a single run can tick just as loudly.
  if (segments.length < 2) {
    return _wrap(Uint8List.sublistView(samples), wav);
  }

  final gain = _driftGain(samples, perChannel);
  final out = _rebuild(samples, segments, gain, perChannel);
  // And again on the finished audio. The level correction multiplies whatever
  // is under it, so a step too small to repair before the gain can be loud
  // enough to hear after it — measured, not supposed: the first pass alone
  // took forty-six steps down to twenty-seven.
  _deClick(out, perChannel);
  return _wrap(Uint8List.fromList(out.expand(_le16).toList()), wav);
}

/// A jump bigger than this between two adjacent samples is a step, not speech.
///
/// Speech moves fast, but not this fast at 24 kHz — and never out of a silence,
/// which is where these are. The same threshold `tool/click_check.dart` counts
/// with, so the tool and the fix are talking about the same thing.
const int _clickJump = 2000;

/// Loud enough on both sides and the jump is a consonant, not a click.
const double _clickQuiet = 0.02;

/// How long to spread a step over. Six milliseconds is far too short to hear
/// as a slur and far too long to hear as a tick.
const int _repairMs = 3;

/// Smooth the steps the voice model leaves in its own output.
///
/// Each one is repaired by replacing a few milliseconds either side with a
/// straight line between the samples that bound it, which turns an instant
/// jump into a ramp. Only where one side is near-silent: a loud consonant may
/// legitimately move the waveform a long way, and flattening those would be
/// audible as a lisp.
///
/// In place, because the caller owns these samples and a copy of a chapter is
/// several megabytes.
void _deClick(Int16List s, int perSecond) {
  final half = max(1, perSecond * _repairMs ~/ 1000);
  var i = 1;
  while (i < s.length) {
    if ((s[i] - s[i - 1]).abs() < _clickJump) {
      i++;
      continue;
    }
    // Quiet on one side of the jump is what makes it a click rather than a
    // transient: a step out of, or into, near-silence.
    if (_peakNear(s, i - perSecond ~/ 100, i) > _clickQuiet &&
        _peakNear(s, i, i + perSecond ~/ 100) > _clickQuiet) {
      i++;
      continue;
    }
    final from = max(0, i - half);
    final to = min(s.length - 1, i + half);
    if (to <= from) {
      i++;
      continue;
    }
    final a = s[from];
    final b = s[to];
    for (var j = from + 1; j < to; j++) {
      s[j] = (a + (b - a) * (j - from) / (to - from)).round();
    }
    // Past the span just rewritten, so one step is not repaired repeatedly.
    i = to + 1;
  }
}

/// The loudest sample in a span, as a fraction of full scale.
double _peakNear(Int16List s, int from, int to) {
  var peak = 0;
  for (var i = max(0, from); i < min(to, s.length); i++) {
    final v = s[i].abs();
    if (v > peak) peak = v;
  }
  return peak / 32768.0;
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
    for (var i = 0; i < smooth.length; i++)
      _headroomLimited(
        s,
        i,
        window,
        smooth[i] <= 0 ? 1.0 : (target / smooth[i]).clamp(1 / ceiling, ceiling),
      ),
  ];
}

/// The loudest a sample may become. Just under full scale, so rounding cannot
/// land on the rail either.
const double _ceilingSample = 32000;

/// The gain for a band, reduced until nothing in it can clip.
///
/// This is the bug that made the polish worse than the thing it fixed. A
/// bedtime narration is not quiet — several cached chapters already peaked at
/// 32767 — so lifting a band by up to 4 dB pushed samples past full scale,
/// where the clamp flattened them. Measured on the real cache: every polished
/// file hit the rail, one of them on 1 260 samples where the original hit it
/// on four. Flattened peaks are hard clipping, and hard clipping is heard as
/// a pop of static — which is exactly where it was reported, at the end of
/// paragraphs, and in the Lunii navigation that encodes the same audio.
///
/// The peak is taken over the band **and its neighbours**, because the gain is
/// interpolated between band centres: a loud sample near a boundary can
/// otherwise be multiplied by the quieter neighbour's larger gain.
double _headroomLimited(Int16List s, int band, int window, double wanted) {
  if (wanted <= 1) return wanted;
  final from = max(0, (band - 1) * window);
  final to = min(s.length, (band + 2) * window);
  var peak = 0;
  for (var i = from; i < to; i++) {
    final v = s[i].abs();
    if (v > peak) peak = v;
  }
  if (peak == 0) return wanted;
  return min(wanted, _ceilingSample / peak);
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
Int16List _rebuild(
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

  /// One sample of the original, with the drift gain applied.
  int gained(int i) =>
      (s[min(i, s.length - 1)] * gainAt(i)).round().clamp(-32768, 32767);

  /// How long to cross into and out of inserted silence. Twelve milliseconds
  /// is long enough that no step remains and short enough to be inaudible as
  /// a fade — it reads as the room going quiet, not as a level moving.
  final fadeLength = max(1, perSecond * 12 ~/ 1000);

  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    for (var j = seg.start; j < seg.end && j < s.length; j++) {
      out.add(gained(j));
    }

    if (i == segments.length - 1) break;
    final gap = segments[i + 1].start - seg.end;
    final keep = gap >= paragraphGap ? max(gap, targetGap) : gap;
    final extra = keep - gap;

    if (extra <= 0) {
      for (var j = 0; j < gap; j++) {
        out.add(gained(seg.end + j));
      }
      continue;
    }

    // Lengthening a gap means splicing silence into it, and the splice is
    // where the click came from. A model's "silence" is not digital zero — it
    // is room tone a few hundred units off the line — so writing a run of
    // exact zeros next to it steps the waveform instantly, twice per gap, and
    // a step is a click. It was audible at the end of every paragraph and in
    // the Lunii navigation, which encodes the same audio.
    //
    // So the silence goes in the MIDDLE of the gap, faded into and out of, and
    // the real room tone stays touching the speech on both sides. Nothing
    // steps, and the pause still lands where the ear expects it.
    final half = gap ~/ 2;
    final fade = min(fadeLength, half);

    for (var j = 0; j < half; j++) {
      final value = gained(seg.end + j);
      final toEnd = half - j;
      out.add(toEnd <= fade ? (value * toEnd / fade).round() : value);
    }
    for (var j = 0; j < extra; j++) {
      out.add(0);
    }
    for (var j = half; j < gap; j++) {
      final value = gained(seg.end + j);
      final fromStart = j - half;
      out.add(fromStart < fade ? (value * fromStart / fade).round() : value);
    }
  }

  // Keep whatever trailed the last segment, so a chapter does not end abruptly.
  for (var j = segments.last.end; j < s.length; j++) {
    out.add((s[j] * gainAt(j)).round().clamp(-32768, 32767));
  }
  return Int16List.fromList(out);
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

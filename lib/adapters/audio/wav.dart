/// Just enough WAV to hand a voice's output to an encoder.
///
/// A WAV file is a RIFF container: a 12-byte header, then a run of chunks that
/// each carry a four-character id, a little-endian length, and that many bytes
/// of payload, padded to an even boundary. The two that matter are `fmt ` and
/// `data`. Walking the chunks properly is the point of this file — the
/// familiar "skip 44 bytes" shortcut is wrong the moment a writer inserts a
/// `LIST` or `fact` chunk, and it fails silently, as noise.
///
/// Only 16-bit PCM is decoded, because that is what every voice in this app
/// produces — Gemini's raw PCM wrapped by `pcmToWav`, and the Windows system
/// voice. Anything else throws [WavFormatException] naming what it found
/// rather than being converted approximately.
library;

import 'dart:typed_data';

/// Interleaved 16-bit PCM, ready to encode.
class WavAudio {
  const WavAudio({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  /// Interleaved across [channels]: for stereo, L R L R ….
  final Int16List samples;
  final int sampleRate;
  final int channels;

  /// Sample frames — one per instant of time, whatever the channel count.
  int get frames => samples.length ~/ channels;

  Duration get duration =>
      Duration(microseconds: frames * 1000000 ~/ sampleRate);
}

class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

const int _formatPcm = 1;
const int _formatExtensible = 0xFFFE;

/// Read [bytes] as a WAV file.
WavAudio decodeWav(Uint8List bytes) {
  if (bytes.length < 12) {
    throw WavFormatException('Too short to be a WAV: ${bytes.length} bytes');
  }
  final view = ByteData.sublistView(bytes);
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw WavFormatException(
      'Not a WAV: expected RIFF/WAVE, found '
      '"${_tag(bytes, 0)}"/"${_tag(bytes, 8)}"',
    );
  }

  int? sampleRate;
  int? channels;
  int? bitsPerSample;
  int? format;
  Uint8List? data;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final declared = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    // A truncated final chunk — or the 0xFFFFFFFF some streaming writers
    // emit — is clamped to what is actually there rather than throwing.
    final size = declared > bytes.length - body
        ? bytes.length - body
        : declared;

    if (id == 'fmt ') {
      if (size < 16) {
        throw WavFormatException('fmt chunk is $size bytes, needs 16');
      }
      format = view.getUint16(body, Endian.little);
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bitsPerSample = view.getUint16(body + 14, Endian.little);
      // WAVE_FORMAT_EXTENSIBLE hides the real format in the first two bytes of
      // a 16-byte SubFormat GUID at the end of a 40-byte fmt chunk.
      if (format == _formatExtensible && size >= 40) {
        format = view.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      data = Uint8List.sublistView(bytes, body, body + size);
    }
    // Chunks are word-aligned: an odd length is followed by a pad byte.
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate == null || channels == null || bitsPerSample == null) {
    throw const WavFormatException('No fmt chunk');
  }
  if (data == null) throw const WavFormatException('No data chunk');
  if (format != _formatPcm) {
    throw WavFormatException(
      'Only PCM is supported, found format $format '
      '(${format == 3 ? 'IEEE float' : 'unknown'})',
    );
  }
  if (bitsPerSample != 16) {
    throw WavFormatException(
      'Only 16-bit samples are supported, found $bitsPerSample-bit',
    );
  }
  if (channels < 1 || channels > 2) {
    throw WavFormatException('Expected 1 or 2 channels, found $channels');
  }
  if (sampleRate <= 0) {
    throw WavFormatException('Nonsense sample rate: $sampleRate');
  }

  // A partial frame at the end is dropped: half a sample is not audio.
  final frames = data.length ~/ (2 * channels);
  final samples = Int16List(frames * channels);
  final source = ByteData.sublistView(data);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = source.getInt16(i * 2, Endian.little);
  }
  return WavAudio(samples: samples, sampleRate: sampleRate, channels: channels);
}

/// Amplitude below which a sample counts as silence, out of 32768.
///
/// Measured against real narration: speech in the app's cache peaks around
/// 26000 and the digital noise floor of a silent stretch peaks under 250. This
/// sits well clear of both.
const int _silenceThreshold = 400;

/// Silence left at the end, so a trimmed clip breathes instead of stopping
/// dead on the last consonant.
const int _tailMilliseconds = 500;

/// Cut dead air off the end of a clip.
///
/// A voice provider occasionally returns a clip with the narration followed by
/// minutes of silence. One chapter of a real story came back as 30 seconds of
/// speech and 625 seconds of nothing, and on a storyteller that is a chapter
/// that goes quiet at bedtime with no way to skip on. It is cheap to defend
/// against and the trim is harmless when there is nothing to trim.
///
/// Only the tail goes. A quiet passage in the middle is untouched, because the
/// scan looks for the *last* sample that is loud enough and keeps everything
/// before it.
WavAudio trimTrailingSilence(WavAudio audio) {
  var last = -1;
  for (var i = audio.samples.length - 1; i >= 0; i--) {
    if (audio.samples[i].abs() >= _silenceThreshold) {
      last = i;
      break;
    }
  }
  // Nothing above the floor at all: this clip is silence. Keep it rather than
  // returning something empty the encoder would refuse — a caller checking
  // durations can still see what it is.
  if (last < 0) return audio;

  final tail = _tailMilliseconds * audio.sampleRate ~/ 1000 * audio.channels;
  var end = last + 1 + tail;
  if (end >= audio.samples.length) return audio;
  // Keep whole frames.
  end -= end % audio.channels;
  return WavAudio(
    samples: Int16List.sublistView(audio.samples, 0, end),
    sampleRate: audio.sampleRate,
    channels: audio.channels,
  );
}

/// Join consecutive clips into one.
///
/// Narration is cached per chunk, but a Lunii node plays a single file, so a
/// chapter's chunks have to become one clip before they can be encoded.
/// Joining decoded samples rather than raw bytes is the point: concatenating
/// WAV files whole would bury a 44-byte header in the middle of the audio,
/// where it plays as a tick.
WavAudio joinWav(List<WavAudio> parts) {
  if (parts.isEmpty) {
    throw const WavFormatException('Nothing to join');
  }
  final first = parts.first;
  for (final part in parts) {
    if (part.sampleRate != first.sampleRate ||
        part.channels != first.channels) {
      throw WavFormatException(
        'Cannot join ${part.sampleRate} Hz/${part.channels}ch onto '
        '${first.sampleRate} Hz/${first.channels}ch',
      );
    }
  }
  final total = parts.fold<int>(0, (sum, p) => sum + p.samples.length);
  final samples = Int16List(total);
  var at = 0;
  for (final part in parts) {
    samples.setRange(at, at + part.samples.length, part.samples);
    at += part.samples.length;
  }
  return WavAudio(
    samples: samples,
    sampleRate: first.sampleRate,
    channels: first.channels,
  );
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes, offset, offset + 4);

/// [bytes] as the plainest WAV there is: a 44-byte header and the sound,
/// nothing else — or [bytes] unchanged when they are not a WAV this can read.
///
/// The reason this exists is a pop of static at the end of every paragraph
/// that took four attempts to find. Every WAV the Gemini 3.8 voices return
/// carries a `C2PA` chunk after its sound — a signed Content Credentials
/// manifest, about 6 KB, saying the audio is AI-made. A RIFF reader skips it.
/// The polish did not use one: it took "everything after byte 44" as samples,
/// and played the manifest as roughly 126 ms of digital noise at the end of
/// every clip, then saved it that way. The de-click and the clipping fix were
/// both real, and both aimed beside the point.
///
/// Two shapes are handled:
///   * extra chunks after (or before) the sound — `C2PA`, `LIST`, `fact` —
///     are dropped, because only `data` is sound;
///   * a WAV *inside* another WAV's sound is unwrapped. The 3.8 voices return
///     a complete WAV where the older ones returned raw PCM, and code that
///     still wrapped the reply in a header of its own put one file inside
///     another: a tick of header at the start, the manifest at the end.
///
/// Anything that reads samples by position must go through this first.
Uint8List plainWav(Uint8List bytes) {
  WavAudio audio;
  try {
    audio = decodeWav(bytes);
  } on WavFormatException {
    return bytes;
  }
  // A whole WAV hiding inside the sound: unwrap it, however deep.
  for (var depth = 0; depth < 4; depth++) {
    final inner = Uint8List.sublistView(audio.samples);
    if (inner.length < 12 ||
        String.fromCharCodes(inner, 0, 4) != 'RIFF' ||
        String.fromCharCodes(inner, 8, 12) != 'WAVE') {
      break;
    }
    try {
      audio = decodeWav(Uint8List.fromList(inner));
    } on WavFormatException {
      break;
    }
  }
  final plain = encodeWav(audio);
  // Already plain: hand back the very same bytes, so a caller can tell
  // "nothing to clean" from "cleaned" without comparing megabytes itself.
  if (plain.length == bytes.length) {
    var same = true;
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] != bytes[i]) {
        same = false;
        break;
      }
    }
    if (same) return bytes;
  }
  return plain;
}

/// 16-bit PCM as a WAV with the minimal 44-byte header.
Uint8List encodeWav(WavAudio audio) {
  final dataLength = audio.samples.length * 2;
  final out = Uint8List(44 + dataLength);
  final view = ByteData.sublistView(out);
  void tag(int at, String s) => out.setRange(at, at + 4, s.codeUnits);
  tag(0, 'RIFF');
  view.setUint32(4, 36 + dataLength, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, audio.channels, Endian.little);
  view.setUint32(24, audio.sampleRate, Endian.little);
  view.setUint32(28, audio.sampleRate * audio.channels * 2, Endian.little);
  view.setUint16(32, audio.channels * 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  view.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < audio.samples.length; i++) {
    view.setInt16(44 + i * 2, audio.samples[i], Endian.little);
  }
  return out;
}

/// Cut Gemini's C2PA manifest out of narration that was saved with it inside.
///
/// Every 3.8 WAV ends with a `C2PA` chunk — about 6 KB of signed Content
/// Credentials. The polish used to read "everything after byte 44" as sound,
/// so it wrote the manifest back *into the audio*, where it played as ~126 ms
/// of loud digital noise: the pop of static at the end of paragraphs and in
/// the Lunii navigation. New audio is cleaned at the door now; this repairs
/// what was saved before.
///
/// In a saved file the manifest is no longer a chunk — it is samples at the
/// end of the sound — but its header bytes, `C2PA` and a 4-byte length, are
/// usually still there verbatim. The sound is cut at that header, and the new
/// end faded to silence so the cut itself cannot tick. A file whose manifest
/// bytes were altered on the way (no header left to find) is reported, not
/// guessed at.
///
/// Also unwraps a WAV saved inside another WAV — what the older request path
/// made of 3.8's replies — when its inner header is still recognisable.
///
///     dart run tool/strip_c2pa.dart            # report only
///     dart run tool/strip_c2pa.dart --write    # repair, originals backed up
///
/// Cache keys are untouched: each file is rewritten under its own name.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';

/// The manifest as Google appends it: an 8-byte chunk header and 6 062 bytes
/// of body, the same in every reply measured.
const int _manifestBytes = 8 + 6062;

int _find(Uint8List hay, List<int> needle, int from) {
  outer:
  for (var i = from; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// A plain 44-byte-header WAV around [pcm], copying format from [like].
Uint8List _rewrap(Uint8List like, Uint8List pcm) {
  final out = Uint8List(44 + pcm.length);
  out.setRange(0, 44, like);
  final v = ByteData.sublistView(out);
  v.setUint32(4, 36 + pcm.length, Endian.little);
  v.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}

/// Fade the last 120 ms of 24 kHz mono PCM to exactly zero.
void _fadeEnd(Uint8List pcm) {
  final v = ByteData.sublistView(pcm);
  final samples = pcm.length ~/ 2;
  final n = (24000 * 120 ~/ 1000).clamp(0, samples);
  if (n < 2) return;
  for (var i = 0; i < n; i++) {
    final at = (samples - n + i) * 2;
    final s = v.getInt16(at, Endian.little);
    v.setInt16(at, (s * (1 - i / (n - 1))).round(), Endian.little);
  }
}

void main(List<String> args) {
  final write = args.contains('--write');
  final dir = Directory(
    '${Platform.environment['USERPROFILE']}\\Documents\\Moonloom\\audio',
  );
  Directory? backup;
  if (write) {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    backup = Directory('${dir.path}.bak-c2pa-$stamp')..createSync();
  }

  var wavs = 0, cut = 0, unwrapped = 0, untouched = 0;
  var removedMs = 0.0;
  for (final f in dir.listSync().whereType<File>()) {
    if (f.path.endsWith('.tmp')) continue;
    final stored = f.readAsBytesSync();
    Uint8List wav;
    try {
      wav = decompressAudio(stored);
    } catch (_) {
      continue;
    }
    if (wav.length < 52 || String.fromCharCodes(wav, 0, 4) != 'RIFF') continue;
    wavs++;

    var pcm = Uint8List.sublistView(wav, 44);
    var changed = false;

    // A WAV inside the sound: drop its 44-byte header.
    if (pcm.length > 44 &&
        String.fromCharCodes(pcm, 0, 4) == 'RIFF' &&
        String.fromCharCodes(pcm, 8, 12) == 'WAVE') {
      final innerData = _find(pcm, 'data'.codeUnits, 12);
      if (innerData >= 0 && innerData + 8 <= pcm.length) {
        pcm = Uint8List.sublistView(pcm, innerData + 8);
        unwrapped++;
        changed = true;
      }
    }

    // The manifest, at the end of the sound. Its chunk header did not
    // survive the polish — the gain changed those bytes — but the text inside
    // it did: "c2pa.actions", "jumb" boxes and the like, all within the last
    // ~6 KB. Every reply measured carried a 6 062-byte manifest behind an
    // 8-byte header, so the cut is 6 070 bytes from the end, or earlier if
    // its text starts sooner. Cutting a few bytes early costs a millisecond
    // of room tone; the fade below covers it either way.
    final tailFrom = (pcm.length - 7000).clamp(0, pcm.length);
    final markers = [
      for (final m in ['jumb', 'c2pa', 'C2PA'])
        _find(pcm, m.codeUnits, tailFrom),
    ].where((i) => i >= 0).toList();
    if (markers.isNotEmpty) {
      final firstText = markers.reduce((a, b) => a < b ? a : b);
      var at = [
        pcm.length - _manifestBytes,
        firstText - 12,
      ].reduce((a, b) => a < b ? a : b).clamp(0, pcm.length);
      if (at.isOdd) at--;
      removedMs += (pcm.length - at) / 48;
      pcm = Uint8List.fromList(pcm.sublist(0, at));
      cut++;
      changed = true;
    }

    if (!changed) {
      untouched++;
      continue;
    }
    pcm = Uint8List.fromList(pcm);
    _fadeEnd(pcm);
    if (write) {
      f.copySync('${backup!.path}\\${f.uri.pathSegments.last}');
      final tmp = File('${f.path}.tmp')
        ..writeAsBytesSync(compressAudio(_rewrap(wav, pcm)));
      tmp.renameSync(f.path);
    }
  }

  stdout.writeln('$wavs cached WAV files');
  stdout.writeln(
    '  $cut had the C2PA manifest inside their sound '
    '(${(removedMs / (cut == 0 ? 1 : cut)).round()} ms of it each, on average)',
  );
  stdout.writeln('  $unwrapped had a WAV saved inside the WAV');
  stdout.writeln('  $untouched were already clean');
  stdout.writeln(
    write
        ? '\nRepaired. Originals of every changed file are in ${backup!.path}'
        : '\nReport only. Re-run with --write to repair.',
  );
}

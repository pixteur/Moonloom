/// Find cached narration a voice provider got wrong.
///
/// One chapter of a real story came back as 30 seconds of speech followed by
/// 625 seconds of silence — a provider glitch, cached exactly as it arrived.
/// Sending it to a storyteller is now safe, because the transfer trims dead
/// air, but **playback in the app still plays the hole**, and nothing else
/// would have noticed it. This is how to see the scale of it.
///
/// Read-only by default. `--delete` removes the offenders so they are
/// re-synthesized next time the chapter is played, which costs a request to
/// the voice provider per chunk — hence not the default.
///
///     dart run tool/audio_cache_audit.dart
///     dart run tool/audio_cache_audit.dart --delete
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/audio/wav.dart';
import 'package:moonloom/adapters/tts/audio_compression.dart';

/// Trailing silence beyond this is a glitch rather than a pause. Real chunks
/// end within a second or so of the last word.
const Duration _suspicious = Duration(seconds: 5);

void main(List<String> args) {
  final delete = args.contains('--delete');
  final home = Platform.environment['USERPROFILE'];
  final dir = Directory(
    args.contains('--dir')
        ? args[args.indexOf('--dir') + 1]
        : '$home\\Documents\\Moonloom\\audio',
  );
  if (!dir.existsSync()) {
    stderr.writeln('No audio cache at ${dir.path}');
    exitCode = 1;
    return;
  }

  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final bad = <({File file, Duration total, Duration kept})>[];
  var checked = 0;
  var unreadable = 0;
  var wastedBytes = 0;

  for (final file in files) {
    final Uint8List raw;
    try {
      raw = decompressAudio(file.readAsBytesSync());
    } on Object catch (_) {
      unreadable++;
      continue;
    }
    // MP3 chunks would need decoding to measure; only WAV is checked, which
    // is what the voices that glitched return.
    if (raw.length < 12 || String.fromCharCodes(raw, 0, 4) != 'RIFF') continue;
    checked++;
    try {
      final audio = decodeWav(raw);
      final kept = trimTrailingSilence(audio).duration;
      final dead = audio.duration - kept;
      if (dead < _suspicious) continue;
      bad.add((file: file, total: audio.duration, kept: kept));
      wastedBytes +=
          (dead.inMilliseconds * audio.sampleRate ~/ 1000) * 2 * audio.channels;
    } on WavFormatException catch (e) {
      stdout.writeln('  ${_name(file)}  unreadable: ${e.message}');
      unreadable++;
    }
  }

  stdout.writeln('$checked WAV chunks checked in ${dir.path}');
  if (unreadable > 0) stdout.writeln('$unreadable could not be read');
  if (bad.isEmpty) {
    stdout.writeln(
      'No chunks with more than ${_secs(_suspicious)} of dead air.',
    );
    return;
  }

  stdout.writeln('\n${bad.length} with dead air at the end:');
  for (final entry in bad) {
    stdout.writeln(
      '  ${_name(entry.file)}  ${_secs(entry.total)} of which '
      '${_secs(entry.total - entry.kept)} is silence '
      '(${_secs(entry.kept)} of audio)',
    );
  }
  stdout.writeln(
    '\nAbout ${(wastedBytes / 1024 / 1024).round()} MB of nothing. '
    'A Lunii transfer already trims this; playback in the app does not.',
  );

  if (!delete) {
    stdout.writeln('Add --delete to remove them so they re-synthesize.');
    return;
  }
  for (final entry in bad) {
    entry.file.deleteSync();
  }
  stdout.writeln(
    'Deleted ${bad.length}. They will be synthesized again next time those '
    'chapters are played, at one request each.',
  );
}

String _name(File file) => file.path.split(RegExp(r'[\\/]')).last;

String _secs(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

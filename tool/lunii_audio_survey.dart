/// Read-only survey of the audio already on an attached Lunii storyteller.
///
/// [docs/lunii-sync.md](../docs/lunii-sync.md) says the device wants "MP3,
/// 44.1 kHz, mono". This measures that against every `sf/` asset on the
/// device, and it is what `lib/adapters/audio/mp3_encoder.dart` encodes to.
///
/// It walks **every frame** of every file, not just the first. Reading only
/// the first frame is a trap: these files are VBR and carry a Xing tag, and a
/// Xing tag lives in a leading frame whose bitrate says nothing about the
/// audio behind it. Sample rate, layer and channel mode do hold from the first
/// frame; bitrate does not.
///
/// Assets are ciphered over their first 512 bytes with the generic key, so the
/// header has to be deciphered before it will parse.
///
/// This never opens the device for writing.
///
///     dart run tool/lunii_audio_survey.dart F:
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/audio/mp3_frame.dart';
import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

void main(List<String> args) {
  final root = args.isEmpty ? 'F:' : args.first;

  final pi = File('$root\\.pi').readAsBytesSync();
  final packs = <String>[
    for (var i = 0; i < pi.length; i += 16)
      pi
          .sublist(i + 12, i + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(),
  ];

  /// Format across every frame of every file — the answer wanted here is a
  /// single entry.
  final formats = <String, int>{};
  final bitrates = <int, int>{};
  final tags = <String, int>{};
  var files = 0;
  var frames = 0;
  var id3 = 0;
  var notAtZero = 0;
  var incomplete = 0;

  for (final pack in packs) {
    final dir = Directory('$root\\.content\\$pack\\sf\\000');
    if (!dir.existsSync()) {
      stdout.writeln('$pack  no sf/000');
      continue;
    }
    final sounds = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final packFormats = <String>{};
    var packFrames = 0;
    var packMin = 1 << 30;
    var packMax = 0;

    for (final sound in sounds) {
      // Only the first sector is ciphered; the tail comes through untouched,
      // so the whole file is walkable after this.
      final bytes = luniiDecipher(sound.readAsBytesSync(), luniiGenericKey);
      files++;
      if (_startsWith(bytes, 'ID3') || _endsWithTagV1(bytes)) id3++;

      final first = Mp3FrameHeader.findFirst(bytes);
      if (first == null) {
        packFormats.add('unparsed');
        continue;
      }
      if (first.offset != 0) notAtZero++;
      tags[_tagOf(bytes, first)] = (tags[_tagOf(bytes, first)] ?? 0) + 1;

      var at = first.offset;
      while (at + 4 <= bytes.length) {
        final header = Mp3FrameHeader.parse(bytes, at);
        if (header == null) break;
        final format =
            '${header.version.label} L${header.layer} '
            '${header.sampleRate}Hz ${header.mode.label}';
        formats[format] = (formats[format] ?? 0) + 1;
        packFormats.add(format);
        bitrates[header.bitrateKbps] = (bitrates[header.bitrateKbps] ?? 0) + 1;
        if (header.bitrateKbps < packMin) packMin = header.bitrateKbps;
        if (header.bitrateKbps > packMax) packMax = header.bitrateKbps;
        at += header.frameLength;
        frames++;
        packFrames++;
      }
      // A walk that stops short means a frame length came out wrong, which
      // would make everything above unreliable.
      if (at != bytes.length) incomplete++;
    }

    stdout.writeln(
      '$pack  ${sounds.length.toString().padLeft(3)} sounds  '
      '${packFrames.toString().padLeft(6)} frames  '
      '${packFormats.join(' / ')}  $packMin–$packMax kbps',
    );
  }

  stdout.writeln(
    '\n── $frames frames in $files sounds across ${packs.length} packs ──',
  );
  for (final e in formats.entries) {
    stdout.writeln('  ${e.value.toString().padLeft(6)}  ${e.key}');
  }
  final rates = bitrates.keys.toList()..sort();
  stdout.writeln(
    '  bitrate: ${rates.map((r) => '$r×${bitrates[r]}').join('  ')}',
  );
  stdout.writeln(
    '  tag: ${tags.entries.map((e) => '${e.key} ${e.value}').join('  ')}',
  );
  stdout.writeln(
    '  ID3: $id3    audio not at byte 0: $notAtZero    '
    'incomplete frame walk: $incomplete',
  );
}

/// LAME writes `Info` in the leading tag frame for constant bitrate and `Xing`
/// for variable, which is the cheapest way to tell the two apart.
String _tagOf(Uint8List bytes, Mp3FrameHeader first) {
  final end = first.offset + first.frameLength;
  final frame = bytes.sublist(
    first.offset,
    end < bytes.length ? end : bytes.length,
  );
  if (_contains(frame, 'Xing')) return 'Xing/VBR';
  if (_contains(frame, 'Info')) return 'Info/CBR';
  return 'untagged';
}

bool _startsWith(Uint8List bytes, String magic) {
  if (bytes.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[i] != magic.codeUnitAt(i)) return false;
  }
  return true;
}

bool _endsWithTagV1(Uint8List bytes) {
  if (bytes.length < 128) return false;
  final at = bytes.length - 128;
  return bytes[at] == 0x54 && bytes[at + 1] == 0x41 && bytes[at + 2] == 0x47;
}

bool _contains(Uint8List bytes, String needle) {
  outer:
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle.codeUnitAt(j)) continue outer;
    }
    return true;
  }
  return false;
}

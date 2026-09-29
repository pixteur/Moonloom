/// Read-only probe against a physically attached Lunii storyteller.
///
/// Validates the cipher in `lib/adapters/lunii/lunii_cipher.dart` against real
/// data before any code goes near *writing* to the device: it deciphers a
/// pack's resource index, which must come out as a run of 12-byte `000\XXXXXXXX`
/// asset paths, and cross-checks the device key by deciphering the pack's `bt`
/// boot file.
///
/// This never opens the device for writing.
///
///     dart run tool/lunii_probe.dart F:
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

void main(List<String> args) {
  final root = args.isEmpty ? 'F:' : args.first;

  final md = File('$root\\.md').readAsBytesSync();
  final pi = File('$root\\.pi').readAsBytesSync();
  stdout.writeln(
    '.md ${md.length} bytes, .pi ${pi.length} bytes '
    '(${pi.length ~/ 16} packs)',
  );

  // Pack dir name is the last 4 bytes of the uuid, uppercase hex.
  final packs = <String>[];
  for (var i = 0; i < pi.length; i += 16) {
    packs.add(
      pi
          .sublist(i + 12, i + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(),
    );
  }
  stdout.writeln('packs: ${packs.join(', ')}\n');

  final key = luniiDeviceKey(md);
  stdout.writeln(
    'device key: ${key.map((w) => '0x${w.toRadixString(16).padLeft(8, '0').toUpperCase()}').join(', ')}\n',
  );

  final dir = '$root\\.content\\${packs.first}';
  stdout.writeln('── pack ${packs.first} ──');

  for (final name in ['ri', 'si']) {
    final raw = File('$dir\\$name').readAsBytesSync();
    final plain = luniiDecipher(raw, luniiGenericKey);
    final entries = plain.length ~/ 12;
    stdout.writeln('$name: ${raw.length} bytes = $entries x 12');
    for (var i = 0; i < (entries < 3 ? entries : 3); i++) {
      stdout.writeln('   [$i] ${_ascii(plain.sublist(i * 12, i * 12 + 12))}');
    }
    final ok = _looksLikeIndex(plain);
    stdout.writeln(
      '   ${ok ? "OK  generic key deciphers $name" : "FAIL not an asset index"}',
    );
  }

  // The boot file is the *ciphered* head of `ri`, re-ciphered with the device
  // key — so deciphering it must reproduce `ri` exactly as stored on disk.
  // That is the check that proves the device key.
  final bt = File('$dir\\bt').readAsBytesSync();
  final riRaw = File('$dir\\ri').readAsBytesSync();
  final btPlain = luniiDecipher(Uint8List.fromList(bt), key);
  final expected = riRaw.sublist(0, _shared(btPlain, riRaw));
  stdout.writeln('\nbt: ${bt.length} bytes');
  stdout.writeln('   bt deciphered : ${_hex(btPlain.sublist(0, 16))}');
  stdout.writeln('   ri on disk    : ${_hex(expected.sublist(0, 16))}');
  stdout.writeln(
    _eq(btPlain.sublist(0, expected.length), expected)
        ? '   OK  device key verified (bt == ciphered head of ri)'
        : '   FAIL device key wrong',
  );

  // And the same key must hold for every pack already on the device.
  final all = packs.every((p) {
    final d = '$root\\.content\\$p';
    final head = File('$d\\ri').readAsBytesSync();
    final boot = File('$d\\bt').readAsBytesSync();
    final plain = luniiDecipher(Uint8List.fromList(boot), key);
    final n = _shared(plain, head);
    return _eq(plain.sublist(0, n), head.sublist(0, n));
  });
  stdout.writeln(
    '   ${all ? "OK" : "FAIL"}  same key verified across all '
    '${packs.length} packs',
  );

  // The node index is the story graph itself. Its header repeats counts we can
  // check independently (node count from the file size, resource counts from
  // ri/si), so a match confirms the layout on real data.
  stdout.writeln('\n── node index, all packs ──');
  for (final pack in packs) {
    final d = '$root\\.content\\$pack';
    // `ni` is stored in the clear — deciphering it would corrupt the header.
    final ni = File('$d\\ni').readAsBytesSync();
    final images =
        luniiDecipher(
          File('$d\\ri').readAsBytesSync(),
          luniiGenericKey,
        ).length ~/
        12;
    final sounds =
        luniiDecipher(
          File('$d\\si').readAsBytesSync(),
          luniiGenericKey,
        ).length ~/
        12;
    final h = ByteData.sublistView(ni);
    final headerSize = h.getUint32(4, Endian.little);
    final nodeSize = h.getUint32(8, Endian.little);
    final nodeCount = h.getUint32(12, Endian.little);
    final imageCount = h.getUint32(16, Endian.little);
    final soundCount = h.getUint32(20, Endian.little);
    final fromSize = (ni.length - headerSize) / nodeSize;
    final ok =
        headerSize == 0x200 &&
        nodeSize == 0x2C &&
        fromSize == nodeCount &&
        imageCount == images &&
        soundCount == sounds;
    stdout.writeln(
      '$pack  hdr=$headerSize node=$nodeSize '
      'nodes=$nodeCount (size says $fromSize)  img=$imageCount/$images  '
      'snd=$soundCount/$sounds  ${ok ? "OK" : "MISMATCH"}',
    );
  }

  // `li` is a flat run of stage-node indices that action nodes slice into, so
  // every value must land inside the node count. That is a strong check that
  // the generic key deciphers it correctly.
  stdout.writeln('\n── list index, all packs ──');
  for (final pack in packs) {
    final d = '$root\\.content\\$pack';
    final nodes = (File('$d\\ni').readAsBytesSync().length - 0x200) ~/ 0x2C;
    final li = luniiDecipher(File('$d\\li').readAsBytesSync(), luniiGenericKey);
    final view = ByteData.sublistView(li);
    final values = [
      for (var i = 0; i * 4 < li.length; i++)
        view.getInt32(i * 4, Endian.little),
    ];
    final inRange = values.every((v) => v >= 0 && v < nodes);
    stdout.writeln(
      '$pack  ${values.length} entries, nodes=$nodes  '
      'first=${values.take(8).toList()}  '
      '${inRange ? "OK all in range" : "OUT OF RANGE"}',
    );
  }

  // One node, byte by byte — to pin down where the control flags sit.
  final ni = File('$dir\\ni').readAsBytesSync();
  stdout.writeln('\n── first 3 nodes of ${packs.first} ──');
  stdout.writeln('header[0..24]: ${_hex(ni.sublist(0, 25))}');
  for (var i = 0; i < 3; i++) {
    final off = 0x200 + i * 0x2C;
    final n = ByteData.sublistView(ni, off, off + 0x2C);
    stdout.writeln('node $i: ${_hex(ni.sublist(off, off + 0x2C))}');
    stdout.writeln(
      '   image=${n.getInt32(0, Endian.little)} '
      'audio=${n.getInt32(4, Endian.little)} '
      'ok=[${n.getInt32(8, Endian.little)},${n.getInt32(12, Endian.little)},'
      '${n.getInt32(16, Endian.little)}] '
      'home=[${n.getInt32(20, Endian.little)},'
      '${n.getInt32(24, Endian.little)},${n.getInt32(28, Endian.little)}] '
      'flags16@32=[${n.getUint16(32, Endian.little)},'
      '${n.getUint16(34, Endian.little)},${n.getUint16(36, Endian.little)},'
      '${n.getUint16(38, Endian.little)},${n.getUint16(40, Endian.little)}] '
      'tail=${_hex(ni.sublist(off + 42, off + 0x2C))}',
    );
  }
}

bool _looksLikeIndex(Uint8List plain) {
  if (plain.length < 12 || plain.length % 12 != 0) return false;
  for (var i = 0; i < plain.length; i += 12) {
    // Every entry is "000\" + 8 hex digits.
    if (_ascii(plain.sublist(i, i + 4)) != '000\\') return false;
  }
  return true;
}

/// How much of `bt` and `ri` can be compared. `bt` is always 64 bytes, but a
/// pack this app wrote whose chapters share one cover has a 12-byte `ri` and
/// the rest of `bt` is padding — so compare the overlap rather than reading
/// off the end of the shorter one.
int _shared(List<int> a, List<int> b) =>
    a.length < b.length ? a.length : b.length;

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _ascii(List<int> bytes) =>
    String.fromCharCodes(bytes.map((b) => b >= 0x20 && b < 0x7f ? b : 0x2e));

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

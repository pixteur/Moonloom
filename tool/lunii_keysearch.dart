/// Read-only search for where the device key hides in a storyteller's `.md`.
///
/// The generic key is already proven (see `tool/lunii_probe.dart`). The device
/// key is only used for a pack's 64-byte `bt` boot file, and `bt` is believed
/// to be the head of that pack's `ri` re-ciphered with it. That gives a known
/// answer to check against, so rather than trusting one documented offset this
/// sweeps every 4-byte-aligned block in `.md` and a handful of word orderings,
/// and reports whichever combination actually reproduces `bt`.
///
///     dart run tool/lunii_keysearch.dart F:
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

/// Orderings to try for pulling four 32-bit words out of the deciphered block.
/// The first is the one the reverse-engineering notes describe.
const _mappings = <List<int>>[
  [16, 20, 8, 12],
  [0, 4, 8, 12],
  [8, 12, 16, 20],
  [16, 20, 0, 4],
  [12, 8, 20, 16],
  [20, 16, 12, 8],
  [4, 0, 12, 8],
  [24, 28, 16, 20],
];

void main(List<String> args) {
  final root = args.isEmpty ? 'F:' : args.first;
  final md = File('$root\\.md').readAsBytesSync();
  final pi = File('$root\\.pi').readAsBytesSync();

  final packs = <String>[];
  for (var i = 0; i < pi.length; i += 16) {
    packs.add(
      pi
          .sublist(i + 12, i + 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(),
    );
  }

  // Candidate answers, per pack: bt should decipher to one of these.
  final targets = <String, List<_Target>>{};
  for (final pack in packs) {
    final dir = '$root\\.content\\$pack';
    final riRaw = File('$dir\\ri').readAsBytesSync();
    final riPlain = luniiDecipher(riRaw, luniiGenericKey);
    final bt = File('$dir\\bt').readAsBytesSync();
    targets[pack] = [
      _Target('ri ciphered head', bt, riRaw.sublist(0, bt.length)),
      _Target('ri plaintext head', bt, riPlain.sublist(0, bt.length)),
    ];
  }

  var found = 0;
  for (var off = 0; off + 0x80 <= md.length; off += 4) {
    final block = luniiDecipher(
      Uint8List.fromList(md.sublist(off, off + 0x80)),
      luniiGenericKey,
    );
    final view = ByteData.sublistView(block);
    for (final map in _mappings) {
      final key = map.map((o) => view.getUint32(o, Endian.little)).toList();
      for (final entry in targets.entries) {
        for (final target in entry.value) {
          if (target.matches(key)) {
            found++;
            stdout.writeln(
              'HIT  .md offset 0x${off.toRadixString(16)}  mapping $map\n'
              '     pack ${entry.key} via ${target.label}\n'
              '     key ${key.map((w) => '0x${w.toRadixString(16).padLeft(8, '0').toUpperCase()}').join(', ')}',
            );
            // Confirm the same key works for every other pack on the device.
            final all = targets.entries.every(
              (e) => e.value.any((t) => t.matches(key)),
            );
            stdout.writeln(
              '     all ${packs.length} packs: ${all ? "OK" : "no"}',
            );
            if (all) return;
          }
        }
      }
    }
  }
  if (found == 0) {
    stdout.writeln(
      'No offset/mapping reproduced bt. '
      'bt is probably not derived from ri — widen the search.',
    );
  }
}

class _Target {
  _Target(this.label, this.bt, this.expected);

  final String label;
  final Uint8List bt;
  final Uint8List expected;

  bool matches(List<int> key) {
    final plain = luniiDecipher(Uint8List.fromList(bt), key);
    if (plain.length != expected.length) return false;
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] != expected[i]) return false;
    }
    return true;
  }
}

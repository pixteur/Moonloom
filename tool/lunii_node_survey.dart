/// Read-only survey of how the packs on a device wire their story graphs.
///
/// Written to answer one question after a written pack played its chapters and
/// then errored: **what does a real pack do at the end of a story?**
/// `device_pack.dart` gives its last chapter no onward transition
/// (`ok = -1,-1,-1`) on the assumption the device then returns to the pack
/// list. This checks that assumption against 9 packs that work.
///
/// Also reports which flag combinations actually occur, since a node with
/// autoplay set and nowhere to go is the specific shape under suspicion.
///
/// This never opens the device for writing.
///
///     dart run tool/lunii_node_survey.dart F:
library;

import 'dart:io';
import 'dart:typed_data';

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

  var total = 0;
  var noOk = 0;
  var noHome = 0;
  var neither = 0;
  var autoplayNoOk = 0;
  final flagCounts = <String, int>{};
  final lastNodes = <String, String>{};

  // A menu is a transition whose count is greater than one: the wheel scrolls
  // that many list entries, and each one is a node with its own prompt. This
  // is the shape a spoken chapter menu has to copy.
  final menus = <String, List<String>>{};

  for (final pack in packs) {
    // `ni` is plaintext.
    final ni = File('$root\\.content\\$pack\\ni').readAsBytesSync();
    final count = (ni.length - 0x200) ~/ 0x2C;

    for (var i = 0; i < count; i++) {
      final n = _Node.read(ni, i);
      total++;
      if (!n.hasOk) noOk++;
      if (!n.hasHome) noHome++;
      if (!n.hasOk && !n.hasHome) neither++;
      if (n.autoplay && !n.hasOk) autoplayNoOk++;
      flagCounts[n.flagSummary] = (flagCounts[n.flagSummary] ?? 0) + 1;
      if (i == count - 1) lastNodes[pack] = n.describe(i);
      if (n.ok[1] > 1 || n.home[1] > 1) {
        (menus[pack] ??= []).add(n.describe(i));
      }
    }
  }

  stdout.writeln('── $total nodes across ${packs.length} packs ──');
  stdout.writeln('  ok  = -1,-1,-1 : $noOk');
  stdout.writeln('  home= -1,-1,-1 : $noHome');
  stdout.writeln('  neither        : $neither   <- our last chapter\'s shape');
  stdout.writeln('  autoplay and no ok: $autoplayNoOk');

  stdout.writeln('\n── flag combinations (wheel,ok,home,pause,autoplay) ──');
  final sorted = flagCounts.entries.toList()..sort((a, b) => b.value - a.value);
  for (final e in sorted) {
    stdout.writeln('  ${e.value.toString().padLeft(5)}  ${e.key}');
  }

  stdout.writeln('\n── the highest-numbered node of each pack ──');
  for (final e in lastNodes.entries) {
    stdout.writeln('  ${e.key}  ${e.value}');
  }

  // The menus themselves, with what the wheel scrolls through. `ok` reads
  // (listIndex, count, offset): count is how many entries the wheel offers and
  // offset is which one it starts on.
  stdout.writeln('\n── nodes offering a choice (count > 1) ──');
  if (menus.isEmpty) {
    stdout.writeln('  none');
  }
  for (final e in menus.entries) {
    stdout.writeln('  ${e.key}  ${e.value.length} such node(s)');
    for (final line in e.value.take(4)) {
      stdout.writeln('    $line');
    }
  }

  // Where a transition can legally point. Node 0 is the pack's square-one
  // screen; if no list entry on the device ever names it, sending the end of
  // a story back there would be unprecedented and worth avoiding.
  stdout.writeln('\n── list index targets ──');
  for (final pack in packs) {
    final li = _decipheredList('$root\\.content\\$pack\\li');
    final zeros = li.where((v) => v == 0).length;
    stdout.writeln(
      '  $pack  ${li.length} entries  min=${li.reduce((a, b) => a < b ? a : b)}'
      '  max=${li.reduce((a, b) => a > b ? a : b)}  '
      'entries naming node 0: $zeros',
    );
  }
}

List<int> _decipheredList(String path) {
  final plain = luniiDecipher(File(path).readAsBytesSync(), luniiGenericKey);
  final view = ByteData.sublistView(plain);
  return [
    for (var i = 0; i * 4 < plain.length; i++)
      view.getInt32(i * 4, Endian.little),
  ];
}

class _Node {
  const _Node(this.image, this.audio, this.ok, this.home, this.flags);

  final int image;
  final int audio;
  final List<int> ok;
  final List<int> home;
  final List<int> flags;

  static _Node read(Uint8List ni, int index) {
    final view = ByteData.sublistView(ni, 0x200 + index * 0x2C);
    return _Node(
      view.getInt32(0x00, Endian.little),
      view.getInt32(0x04, Endian.little),
      [for (var f = 0; f < 3; f++) view.getInt32(0x08 + f * 4, Endian.little)],
      [for (var f = 0; f < 3; f++) view.getInt32(0x14 + f * 4, Endian.little)],
      [for (var f = 0; f < 5; f++) view.getUint16(0x20 + f * 2, Endian.little)],
    );
  }

  bool get hasOk => ok[0] != -1;
  bool get hasHome => home[0] != -1;
  bool get autoplay => flags[4] == 1;

  String get flagSummary => flags.join(',');

  String describe(int index) =>
      'node $index  image=$image audio=$audio '
      'ok=$ok home=$home flags=$flagSummary';
}

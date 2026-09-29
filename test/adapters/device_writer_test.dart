import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/lunii/device_pack.dart';
import 'package:moonloom/adapters/lunii/device_writer.dart';
import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

/// The write protocol, exercised against a storyteller-shaped directory in a
/// temp folder. What is being checked is the *order* and the *blast radius*:
/// `.pi` grows last and by exactly sixteen bytes, `.cfg` is never opened, and
/// anything that does not look like a device is refused outright.
///
/// A real device is the only place the firmware's opinion can be had, but
/// everything that could damage one is decidable here.
void main() {
  late Directory temp;
  late String root;

  Uint8List mp3() {
    final bytes = Uint8List(417 * 2);
    for (var i = 0; i < 2; i++) {
      bytes.setRange(i * 417, i * 417 + 4, [0xFF, 0xFB, 0x90, 0xC0]);
    }
    return bytes;
  }

  DevicePack pack({int seed = 7, int chapters = 2}) => buildDevicePack(
    chapters: [
      for (var i = 0; i < chapters; i++) DevicePackChapter(audio: mp3()),
    ],
    deviceKey: LuniiDevice.open(root).deviceKey,
    cover: IndexedImage(
      width: 320,
      height: 240,
      pixels: Uint8List(320 * 240),
      palette: const [0x000000],
    ),
    rng: Random(seed),
  );

  /// A device with [packs] already installed, plus a `.cfg` to watch.
  ///
  /// `.md` is arbitrary bytes: the key derivation just deciphers them, so any
  /// 512 bytes yield *a* key, and that is enough to write and read back with.
  void makeDevice({int packs = 0}) {
    root = temp.path;
    final md = Uint8List(0x200);
    for (var i = 0; i < md.length; i++) {
      md[i] = (i * 31 + 7) & 0xFF;
    }
    File('$root/.md').writeAsBytesSync(md);
    File('$root/.pi').writeAsBytesSync(Uint8List(0));
    File('$root/.cfg').writeAsStringSync('volume=3\nsleep=20\n');
    File('$root/version').writeAsStringSync('2020-11-27 14:51 UTC\n');
    Directory('$root/.content').createSync();

    for (var i = 0; i < packs; i++) {
      writePack(
        LuniiDevice.open(root),
        pack(seed: 100 + i),
        backupDirectory: '$root/../backup-seed',
      );
    }
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lunii_write_test');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('opening a device', () {
    test('reads the pack list and the firmware string', () {
      makeDevice();
      final device = LuniiDevice.open(root);
      expect(device.packIds, isEmpty);
      expect(device.firmware, '2020-11-27 14:51 UTC');
      expect(device.deviceKey.length, 4);
    });

    test('refuses a directory that is not a storyteller', () {
      root = temp.path;
      expect(
        () => LuniiDevice.open(root),
        throwsA(isA<LuniiDeviceException>()),
      );
    });

    test('refuses a .pi that is not a whole number of pack ids', () {
      makeDevice();
      File('$root/.pi').writeAsBytesSync(Uint8List(20));
      expect(
        () => LuniiDevice.open(root),
        throwsA(
          isA<LuniiDeviceException>().having(
            (e) => e.message,
            'message',
            contains('pack ids'),
          ),
        ),
      );
    });

    test('refuses a key that does not match an installed pack', () {
      makeDevice(packs: 1);
      // Rewriting .md changes the derived key; the bt of the pack already
      // there will no longer decipher to its ri.
      final md = File('$root/.md').readAsBytesSync();
      md[0x100] ^= 0xFF;
      File('$root/.md').writeAsBytesSync(md);
      expect(
        () => LuniiDevice.open(root),
        throwsA(
          isA<LuniiDeviceException>().having(
            (e) => e.message,
            'message',
            contains('does not match'),
          ),
        ),
      );
    });
  });

  group('planning', () {
    test('lists every file and touches nothing', () {
      makeDevice();
      final device = LuniiDevice.open(root);
      final p = pack();
      final plan = planWrite(device, p);
      expect(plan.files.length, p.files.length);
      expect(plan.bytes, p.byteCount);
      expect(plan.packsBefore, 0);
      expect(Directory(plan.packDirectory).existsSync(), isFalse);
      expect(File('$root/.pi').lengthSync(), 0);
    });

    test('refuses a pack that is already installed', () {
      makeDevice();
      final p = pack();
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');
      expect(
        () => planWrite(LuniiDevice.open(root), p),
        throwsA(
          isA<LuniiDeviceException>().having(
            (e) => e.message,
            'message',
            contains('already installed'),
          ),
        ),
      );
    });

    test('refuses a leftover directory .pi does not list', () {
      makeDevice();
      final device = LuniiDevice.open(root);
      final p = pack();
      Directory(
        '$root/.content/${p.directoryName}',
      ).createSync(recursive: true);
      expect(
        () => planWrite(device, p),
        throwsA(
          isA<LuniiDeviceException>().having(
            (e) => e.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });
  });

  group('writing', () {
    test('creates the whole tree and lists it in .pi', () {
      makeDevice();
      final p = pack(chapters: 3);
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');

      final dir = '$root/.content/${p.directoryName}';
      for (final name in ['ni', 'li', 'ri', 'si', 'bt', 'nm']) {
        expect(File('$dir/$name').existsSync(), isTrue, reason: name);
      }
      expect(Directory('$dir/sf/000').listSync().length, 3);
      expect(Directory('$dir/rf/000').listSync().length, 1);

      final after = LuniiDevice.open(root);
      expect(after.packIds.length, 1);
      expect(after.packDirectories, [p.directoryName]);
    });

    test('.pi grows by exactly sixteen bytes, appended', () {
      makeDevice(packs: 2);
      final before = File('$root/.pi').readAsBytesSync();
      final p = pack(seed: 42);
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');
      final after = File('$root/.pi').readAsBytesSync();

      expect(after.length, before.length + 16);
      expect(
        after.sublist(0, before.length),
        before,
        reason: 'the ids already there are copied through untouched',
      );
      expect(after.sublist(before.length), p.uuid);
    });

    test('a hidden .pi is still appendable', () {
      // On a real device every root file carries the Hidden attribute, and
      // Windows refuses the CREATE_ALWAYS that writeAsBytes uses on one —
      // "Access is denied". Appending to the existing file is fine. This cost
      // a failed write to find, so it is pinned here.
      makeDevice(packs: 1);
      Process.runSync('attrib', ['+h', '$root\\.pi']);
      addTearDown(() => Process.runSync('attrib', ['-h', '$root\\.pi']));

      final before = File('$root/.pi').readAsBytesSync();
      final p = pack(seed: 21);
      expect(
        () => writePack(
          LuniiDevice.open(root),
          p,
          backupDirectory: '${temp.path}/b',
        ),
        returnsNormally,
      );
      final after = File('$root/.pi').readAsBytesSync();
      expect(after.length, before.length + 16);
      expect(after.sublist(0, before.length), before);
      expect(after.sublist(before.length), p.uuid);
    }, testOn: 'windows');

    test('.cfg is never opened', () {
      makeDevice(packs: 1);
      final cfg = File('$root/.cfg');
      final content = cfg.readAsStringSync();
      final modified = cfg.lastModifiedSync();
      writePack(
        LuniiDevice.open(root),
        pack(seed: 9),
        backupDirectory: '${temp.path}/b',
      );
      expect(cfg.readAsStringSync(), content);
      expect(cfg.lastModifiedSync(), modified);
    });

    test('the packs already installed are left alone', () {
      makeDevice(packs: 2);
      final existing = <String, List<int>>{};
      for (final dir in Directory('$root/.content').listSync()) {
        for (final f in Directory(dir.path).listSync(recursive: true)) {
          if (f is File) existing[f.path] = f.readAsBytesSync();
        }
      }
      writePack(
        LuniiDevice.open(root),
        pack(seed: 77),
        backupDirectory: '${temp.path}/b',
      );
      for (final entry in existing.entries) {
        expect(
          File(entry.key).readAsBytesSync(),
          entry.value,
          reason: '${entry.key} changed',
        );
      }
    });

    test('backs up .pi and .md before writing', () {
      makeDevice(packs: 1);
      final backup = '${temp.path}/backup';
      final piBefore = File('$root/.pi').readAsBytesSync();
      writePack(LuniiDevice.open(root), pack(seed: 5), backupDirectory: backup);
      expect(File('$backup/pi.bak').readAsBytesSync(), piBefore);
      expect(
        File('$backup/md.bak').readAsBytesSync(),
        File('$root/.md').readAsBytesSync(),
      );
    });

    test('what lands on disk is what the pack said, byte for byte', () {
      makeDevice();
      final p = pack();
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');
      final dir = '$root/.content/${p.directoryName}';
      for (final entry in p.files.entries) {
        expect(
          File('$dir/${entry.key}').readAsBytesSync(),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('removing a pack unlists it first, then deletes it', () {
      makeDevice(packs: 2);
      final p = pack(seed: 31);
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');
      final before = File('$root/.pi').readAsBytesSync();
      expect(LuniiDevice.open(root).packIds.length, 3);

      final deleted = removePack(
        LuniiDevice.open(root),
        p.uuid,
        backupDirectory: '${temp.path}/b2',
      );
      expect(deleted, greaterThan(0));

      final after = LuniiDevice.open(root);
      expect(after.packIds.length, 2);
      expect(after.packDirectories, isNot(contains(p.directoryName)));
      expect(
        Directory('$root/.content/${p.directoryName}').existsSync(),
        isFalse,
      );
      // Shortening .pi is the only place this code makes a file smaller, and
      // it goes through truncate-then-write on a handle. Check the length on
      // its own: when that write landed at the wrong offset the file came back
      // as the old length plus the new content, zero-padded in front, and the
      // byte comparison alone made that look like scrambled ids.
      expect(File('$root/.pi').lengthSync(), 32);
      // The two survivors keep their ids, in order.
      expect(File('$root/.pi').readAsBytesSync(), before.sublist(0, 32));
    });

    test('removing refuses a pack that is not installed', () {
      makeDevice(packs: 1);
      expect(
        () => removePack(
          LuniiDevice.open(root),
          Uint8List(16),
          backupDirectory: '${temp.path}/b',
        ),
        throwsA(isA<LuniiDeviceException>()),
      );
    });

    test('a hidden .pi can still be shortened', () {
      makeDevice(packs: 1);
      final p = pack(seed: 55);
      writePack(LuniiDevice.open(root), p, backupDirectory: '${temp.path}/b');
      Process.runSync('attrib', ['+h', '$root\\.pi']);
      addTearDown(() => Process.runSync('attrib', ['-h', '$root\\.pi']));
      expect(
        () => removePack(
          LuniiDevice.open(root),
          p.uuid,
          backupDirectory: '${temp.path}/b2',
        ),
        returnsNormally,
      );
      expect(LuniiDevice.open(root).packIds.length, 1);
    }, testOn: 'windows');

    test('the written pack satisfies the probe\'s bt identity on re-open', () {
      // The check that a pack belongs to this device, run against what was
      // actually written rather than what was in memory.
      makeDevice();
      final p = pack();
      final device = LuniiDevice.open(root);
      writePack(device, p, backupDirectory: '${temp.path}/b');
      final dir = '$root/.content/${p.directoryName}';
      final bt = luniiDecipher(
        File('$dir/bt').readAsBytesSync(),
        device.deviceKey,
      );
      final ri = File('$dir/ri').readAsBytesSync();
      // bt is always 64 bytes; this pack's ri is 12, the rest being padding.
      expect(bt.sublist(0, ri.length), ri);
      // And re-opening re-runs that check across installed packs.
      expect(() => LuniiDevice.open(root), returnsNormally);
    });
  });
}

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/image/bmp_rle4.dart';
import 'package:moonloom/adapters/lunii/device_pack.dart';
import 'package:moonloom/adapters/lunii/lunii_cipher.dart';

/// A built pack has to survive exactly the checks `tool/lunii_probe.dart` runs
/// against a real storyteller, because those are the ones that were verified
/// on hardware. So these are the probe's assertions, turned inward: the
/// indexes decipher into asset paths, `bt` reproduces the head of `ri`, the
/// node index is plaintext with counts that agree with `ri`/`si`, and every
/// list entry lands on a node that exists.
///
/// The device key here is invented. It only ever protects `bt`, and `bt`'s
/// correctness is checked by round-tripping it, so a real one buys nothing.
void main() {
  const deviceKey = [0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210];

  /// A byte run that opens with a real MPEG-1 Layer III / 44100 / mono frame
  /// header, which is what the builder checks before it will accept audio.
  Uint8List mp3({int frames = 3}) {
    final bytes = Uint8List(frames * 417);
    for (var i = 0; i < frames; i++) {
      bytes.setRange(i * 417, i * 417 + 4, [0xFF, 0xFB, 0x90, 0xC0]);
    }
    return bytes;
  }

  IndexedImage picture({int shade = 3}) => IndexedImage(
    width: 320,
    height: 240,
    pixels: Uint8List(320 * 240)..fillRange(0, 320 * 240, shade),
    palette: [for (var i = 0; i < 16; i++) 0x111111 * i],
  );

  DevicePack build({int chapters = 3, bool withCover = true}) =>
      buildDevicePack(
        chapters: [
          for (var i = 0; i < chapters; i++)
            DevicePackChapter(audio: mp3(frames: i + 1)),
        ],
        deviceKey: deviceKey,
        cover: withCover ? picture() : null,
        rng: Random(7),
      );

  /// The 12-byte `000\XXXXXXXX` entries an index deciphers into.
  List<String> entries(Uint8List ciphered) {
    final plain = luniiDecipher(ciphered, luniiGenericKey);
    return [
      for (var i = 0; i * 12 < plain.length; i++)
        String.fromCharCodes(plain, i * 12, i * 12 + 12),
    ];
  }

  group('the file tree', () {
    test('is exactly the eight entries a device pack has', () {
      final pack = build();
      final top = pack.files.keys.map((p) => p.split('/').first).toSet();
      expect(top, {'ni', 'li', 'ri', 'si', 'bt', 'nm', 'rf', 'sf'});
    });

    test('names itself from the last four bytes of the uuid', () {
      final pack = buildDevicePack(
        chapters: [DevicePackChapter(audio: mp3())],
        deviceKey: deviceKey,
        uuid: Uint8List.fromList([
          ...List.filled(12, 0),
          0xB3,
          0x94,
          0x1E,
          0xE8,
        ]),
        rng: Random(1),
      );
      expect(pack.directoryName, 'B3941EE8');
    });

    test('nm is empty and bt is 64 bytes', () {
      final pack = build();
      expect(pack.files['nm']!.length, 0);
      expect(pack.files['bt']!.length, 0x40);
    });

    test('has one asset file per index entry, named to match', () {
      final pack = build(chapters: 4);
      for (final index in ['ri', 'si']) {
        final folder = index == 'ri' ? 'rf' : 'sf';
        for (final entry in entries(pack.files[index]!)) {
          expect(entry.substring(0, 4), '000\\');
          expect(
            pack.files.keys,
            contains('$folder/000/${entry.substring(4)}'),
            reason: '$index entry "$entry" has no file',
          );
        }
      }
    });
  });

  group('ciphering', () {
    test('ni is left in the clear — deciphering it corrupts the header', () {
      // The trap: `ni` is an index like the others and the reverse-engineering
      // notes list it among the encrypted files. Its header must parse as-is.
      final ni = build().files['ni']!;
      final view = ByteData.sublistView(ni);
      expect(view.getUint16(0x00, Endian.little), 1, reason: 'format version');
      expect(view.getUint16(0x02, Endian.little), 2, reason: 'pack version');
      expect(view.getUint32(0x04, Endian.little), 0x200, reason: 'header size');
      expect(view.getUint32(0x08, Endian.little), 0x2C, reason: 'node size');
      expect(view.getUint8(0x18), 0, reason: 'control byte');
    });

    test('ri and si decipher into asset paths, which is the probe check', () {
      final pack = build(chapters: 3);
      // A cover plus three chapters that share it: one image, three sounds.
      expect(entries(pack.files['ri']!).length, 1);
      expect(entries(pack.files['si']!).length, 3);
      for (final entry in [
        ...entries(pack.files['ri']!),
        ...entries(pack.files['si']!),
      ]) {
        expect(entry, matches(r'^000\\[0-9A-F]{8}$'));
      }
    });

    test('bt deciphers to the head of ri exactly as ri is stored', () {
      // This identity is what proves a device key is the right one, and it is
      // the check lunii_probe runs against every pack on a device. Six images
      // is where ri first exceeds bt's 64 bytes, which is the shape every real
      // pack has.
      final pack = buildDevicePack(
        chapters: [
          for (var i = 0; i < 6; i++)
            DevicePackChapter(
              audio: mp3(),
              image: picture(shade: i),
            ),
        ],
        deviceKey: deviceKey,
        rng: Random(11),
      );
      expect(pack.files['ri']!.length, greaterThan(0x40));
      expect(
        luniiDecipher(pack.files['bt']!, deviceKey),
        pack.files['ri']!.sublist(0, 0x40),
      );
    });

    test('a short ri is zero-padded into bt, which stays 64 bytes', () {
      // No pack on the device has an ri shorter than bt, so what the firmware
      // makes of this is an open question. What is pinned here is only that
      // the file keeps its size and the bytes ri does have survive.
      final pack = build();
      final ri = pack.files['ri']!;
      expect(ri.length, 12, reason: 'one shared cover');
      final bt = luniiDecipher(pack.files['bt']!, deviceKey);
      expect(bt.length, 0x40);
      expect(bt.sublist(0, 12), ri);
      expect(bt.sublist(12), everyElement(0));
    });

    test('a different device key gives a different bt, and nothing else', () {
      final a = build();
      final b = buildDevicePack(
        chapters: [
          for (var i = 0; i < 3; i++)
            DevicePackChapter(audio: mp3(frames: i + 1)),
        ],
        deviceKey: const [1, 2, 3, 4],
        cover: picture(),
        rng: Random(7),
      );
      expect(b.files['bt'], isNot(a.files['bt']));
      expect(b.files['ri'], a.files['ri']);
      expect(b.files['ni'], a.files['ni']);
    });

    test('the assets themselves are ciphered, and come back', () {
      final pack = build();
      final image = pack.files.entries.firstWhere(
        (e) => e.key.startsWith('rf/'),
      );
      expect(image.value[0], isNot(0x42), reason: 'a plain BMP would say BM');
      final plain = luniiDecipher(image.value, luniiGenericKey);
      expect(decodeBmpRle4(plain).width, 320);

      final sound = pack.files.entries.firstWhere(
        (e) => e.key.startsWith('sf/'),
      );
      expect(luniiDecipher(sound.value, luniiGenericKey).sublist(0, 4), [
        0xFF,
        0xFB,
        0x90,
        0xC0,
      ]);
    });
  });

  group('the node graph', () {
    /// Read the node index back the way the device would.
    ({int nodes, int images, int sounds}) header(Uint8List ni) {
      final view = ByteData.sublistView(ni);
      return (
        nodes: view.getUint32(0x0C, Endian.little),
        images: view.getUint32(0x10, Endian.little),
        sounds: view.getUint32(0x14, Endian.little),
      );
    }

    List<int> node(Uint8List ni, int i) {
      final view = ByteData.sublistView(ni, 0x200 + i * 0x2C);
      return [
        for (var f = 0; f < 8; f++) view.getInt32(f * 4, Endian.little),
        for (var f = 0; f < 5; f++) view.getUint16(0x20 + f * 2, Endian.little),
      ];
    }

    test('the cover is silent when no spoken title is given', () {
      final ni = build(chapters: 3).files['ni']!;
      expect(node(ni, 0)[1], -1, reason: 'no sound on the cover');
      // Chapter i is sound i when nothing precedes it.
      for (var i = 0; i < 3; i++) {
        expect(node(ni, i + 1)[1], i);
      }
      expect(header(ni).sounds, 3);
    });

    test('a spoken title becomes sound 0 and shifts the chapters', () {
      // The device has no screen, so the cover saying the story's name is the
      // only way a child knows which pack they are standing on. It goes first,
      // which moves every chapter along one — the bug this guards is a pack
      // whose chapter 1 plays the title and whose last chapter plays nothing.
      final pack = buildDevicePack(
        chapters: [
          for (var i = 0; i < 3; i++)
            DevicePackChapter(audio: mp3(frames: i + 2)),
        ],
        deviceKey: deviceKey,
        cover: picture(),
        titleAudio: mp3(frames: 1),
        rng: Random(7),
      );
      final ni = pack.files['ni']!;
      expect(header(ni).sounds, 4, reason: 'title + three chapters');
      expect(node(ni, 0)[1], 0, reason: 'the cover says the title');
      for (var i = 0; i < 3; i++) {
        expect(node(ni, i + 1)[1], i + 1, reason: 'chapter ${i + 1} shifted');
      }
      // The end node says it again, so the story audibly comes to rest.
      expect(node(ni, 4)[1], 0);
    });

    test('a title in the wrong format is named as the title', () {
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: mp3())],
          deviceKey: deviceKey,
          titleAudio: Uint8List(64), // not an MP3 frame
        ),
        throwsA(
          isA<DevicePackException>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('spoken title'), isNot(contains('Chapter 0'))),
          ),
        ),
      );
    });

    test('announcing chapters turns the cover into a menu', () {
      // The shape comes from `tool/lunii_node_survey.dart` over a real device:
      // a menu is a transition whose count is above one, its options are the
      // list entries from there on, and each option is a node with its own
      // short prompt. Walked here the way the device walks it.
      final pack = buildDevicePack(
        chapters: [
          for (var i = 0; i < 3; i++)
            DevicePackChapter(
              audio: mp3(frames: i + 2),
              announce: mp3(frames: 1),
            ),
        ],
        deviceKey: deviceKey,
        cover: picture(),
        titleAudio: mp3(frames: 1),
        rng: Random(7),
      );
      final ni = pack.files['ni']!;
      final li = ByteData.sublistView(
        luniiDecipher(pack.files['li']!, luniiGenericKey),
      );
      int entry(int i) => li.getInt32(i * 4, Endian.little);

      // cover + 3 announce + 3 chapters + end
      expect(header(ni).nodes, 8);
      // title + 3 announce + 3 chapters
      expect(header(ni).sounds, 7);

      final cover = node(ni, 0);
      expect(cover[3], 3, reason: 'the wheel offers all three chapters');
      expect(cover[8], 1, reason: 'wheel on');

      // Every option speaks, and OK on it lands on a distinct chapter that
      // plays a different sound from the announcement.
      final chapterNodes = <int>{};
      for (var option = 0; option < 3; option++) {
        final announce = entry(cover[2] + option);
        final a = node(ni, announce);
        expect(a[1], isNot(-1), reason: 'option $option says its name');
        expect(a[12], 0, reason: 'an announcement does not autoplay');
        final chapter = entry(a[2]);
        chapterNodes.add(chapter);
        final c = node(ni, chapter);
        expect(c[12], 1, reason: 'the chapter itself autoplays');
        expect(c[1], isNot(a[1]), reason: 'chapter audio, not the name again');
      }
      expect(chapterNodes, hasLength(3), reason: 'three distinct chapters');

      // Chapters still run on into each other, ending at the end node.
      final first = chapterNodes.reduce((a, b) => a < b ? a : b);
      var at = first;
      final played = <int>[];
      for (var i = 0; i < 3; i++) {
        played.add(at);
        at = entry(node(ni, at)[2]);
      }
      expect(played.toSet(), chapterNodes);
      expect(at, header(ni).nodes - 1, reason: 'the last leads to the end');
    });

    test('one chapter without a name leaves the pack a straight line', () {
      // Half a menu is worse than none: a wheel that speaks some options and
      // is silent on others gives a child no way to tell where they are.
      final pack = buildDevicePack(
        chapters: [
          DevicePackChapter(audio: mp3(), announce: mp3()),
          DevicePackChapter(audio: mp3()),
        ],
        deviceKey: deviceKey,
        cover: picture(),
        rng: Random(7),
      );
      final ni = pack.files['ni']!;
      expect(header(ni).nodes, 4, reason: 'cover + 2 chapters + end');
      expect(node(ni, 0)[3], 1, reason: 'no choice offered');
      expect(header(ni).sounds, 2, reason: 'the announcement is not shipped');
    });

    test('no node is left with nowhere to go', () {
      // This is the one that matters. A pack whose last chapter had no onward
      // transition played every chapter on real hardware and then threw up an
      // error screen: autoplay follows the ok transition, and -1 is not a
      // place. Across 490 nodes in nine working packs, not one has neither an
      // ok nor a home transition.
      final pack = build(chapters: 5);
      final ni = pack.files['ni']!;
      final nodes = header(ni).nodes;
      final li = ByteData.sublistView(
        luniiDecipher(pack.files['li']!, luniiGenericKey),
      );
      for (var i = 0; i < nodes; i++) {
        final n = node(ni, i);
        final ok = n.sublist(2, 5);
        final home = n.sublist(5, 8);
        final autoplay = n[12] == 1;
        expect(
          ok[0] != -1 || home[0] != -1,
          isTrue,
          reason: 'node $i has neither transition',
        );
        if (autoplay) {
          expect(ok[0], isNot(-1), reason: 'node $i autoplays into nothing');
        }
        // And wherever it points has to exist.
        for (final t in [ok, home]) {
          if (t[0] == -1) continue;
          for (var o = 0; o < t[1]; o++) {
            final target = li.getInt32((t[0] + o) * 4, Endian.little);
            expect(target, greaterThanOrEqualTo(0));
            expect(
              target,
              lessThan(nodes),
              reason: 'node $i points off the end',
            );
          }
        }
      }
    });

    test('the story ends somewhere quiet, and OK replays it', () {
      final pack = build(chapters: 3);
      final ni = pack.files['ni']!;
      final li = ByteData.sublistView(
        luniiDecipher(pack.files['li']!, luniiGenericKey),
      );
      final last = header(ni).nodes - 1;
      final end = node(ni, last);
      expect(end[0], 0, reason: 'the end shows the cover again');
      expect(end[1], -1, reason: 'in silence');
      expect(end[12], 0, reason: 'and does not autoplay onward');
      // Its OK goes back to the first chapter.
      final t = end.sublist(2, 5);
      expect(li.getInt32(t[0] * 4, Endian.little), 1);
    });

    test('no list entry names node 0, as none does on the device', () {
      final pack = build(chapters: 4);
      final li = luniiDecipher(pack.files['li']!, luniiGenericKey);
      final view = ByteData.sublistView(li);
      for (var i = 0; i * 4 < li.length; i++) {
        expect(view.getInt32(i * 4, Endian.little), isNot(0));
      }
    });

    test('the counts in the header match ri, si and the file size', () {
      final pack = build(chapters: 4);
      final ni = pack.files['ni']!;
      final h = header(ni);
      expect(h.nodes, 6, reason: 'a cover, four chapters and the end');
      expect(h.images, entries(pack.files['ri']!).length);
      expect(h.sounds, entries(pack.files['si']!).length);
      expect(ni.length, 0x200 + h.nodes * 0x2C);
      expect(pack.nodeCount, h.nodes);
    });

    test('every list entry lands on a node that exists', () {
      final pack = build(chapters: 4);
      final nodes = header(pack.files['ni']!).nodes;
      final li = luniiDecipher(pack.files['li']!, luniiGenericKey);
      final view = ByteData.sublistView(li);
      expect(li.length % 4, 0);
      for (var i = 0; i * 4 < li.length; i++) {
        final target = view.getInt32(i * 4, Endian.little);
        expect(target, greaterThanOrEqualTo(0));
        expect(target, lessThan(nodes));
      }
    });

    test('the cover shows the picture, plays nothing, and waits for OK', () {
      final n = node(build().files['ni']!, 0);
      expect(n[0], 0, reason: 'image index 0, the cover');
      expect(n[1], -1, reason: 'no audio: a generated story has no jingle');
      expect(n.sublist(2, 5), [0, 1, 0], reason: 'ok → the first list entry');
      expect(n.sublist(5, 8), [-1, -1, -1], reason: 'no home transition');
      // wheel,ok,home,pause,autoplay — the shape node 0 has on all nine packs
      // already on the device.
      expect(n.sublist(8), [1, 1, 0, 0, 0]);
    });

    test('chapters autoplay and chain in a straight line', () {
      final ni = build(chapters: 3).files['ni']!;
      final li = luniiDecipher(ni.sublist(0, 0), luniiGenericKey); // unused
      expect(li, isEmpty);
      for (var i = 1; i <= 3; i++) {
        final n = node(ni, i);
        expect(n[1], i - 1, reason: 'chapter $i plays sound ${i - 1}');
        expect(n[12], 1, reason: 'chapter $i autoplays');
        expect(n[10], 1, reason: 'chapter $i offers home');
        expect(n[11], 1, reason: 'chapter $i can be paused');
      }
    });

    test('the last chapter hands on to the end rather than dangling', () {
      final ni = build(chapters: 3).files['ni']!;
      final li = ByteData.sublistView(
        luniiDecipher(build(chapters: 3).files['li']!, luniiGenericKey),
      );
      final t = node(ni, 3).sublist(2, 5);
      expect(
        t,
        isNot([-1, -1, -1]),
        reason: 'this is what errored on hardware',
      );
      expect(li.getInt32(t[0] * 4, Endian.little), 4, reason: 'the end node');
      expect(node(ni, 3)[12], 1, reason: 'and it still autoplays there');
    });

    test(
      'following the list from the cover walks the whole story, then rests',
      () {
        final pack = build(chapters: 5);
        final ni = pack.files['ni']!;
        final li = ByteData.sublistView(
          luniiDecipher(pack.files['li']!, luniiGenericKey),
        );
        final visited = <int>[];
        var at = 0;
        // Walk until somewhere repeats — a straight line that loops home rather
        // than one that runs off the end.
        while (!visited.contains(at) && visited.length < 20) {
          visited.add(at);
          final t = node(ni, at).sublist(2, 5);
          if (t[0] == -1) break;
          at = li.getInt32((t[0] + t[2]) * 4, Endian.little);
        }
        expect(visited, [
          0,
          1,
          2,
          3,
          4,
          5,
          6,
        ], reason: 'cover, five chapters, the end');
        expect(at, 1, reason: 'and the end leads back to chapter one');
      },
    );
  });

  group('per-chapter pictures', () {
    test('a chapter with its own image gets its own index', () {
      final pack = buildDevicePack(
        chapters: [
          DevicePackChapter(audio: mp3(), image: picture(shade: 1)),
          DevicePackChapter(audio: mp3()),
          DevicePackChapter(audio: mp3(), image: picture(shade: 2)),
        ],
        deviceKey: deviceKey,
        cover: picture(),
        rng: Random(3),
      );
      final ni = pack.files['ni']!;
      int imageOf(int i) =>
          ByteData.sublistView(ni, 0x200 + i * 0x2C).getInt32(0, Endian.little);
      // Cover is 0; chapters 1 and 3 add their own; chapter 2 falls back.
      expect(entries(pack.files['ri']!).length, 3);
      expect(imageOf(1), 1);
      expect(imageOf(2), 0);
      expect(imageOf(3), 2);
    });

    test('with no cover and no chapter images there are no images at all', () {
      final pack = build(chapters: 2, withCover: false);
      expect(entries(pack.files['ri']!), isEmpty);
      expect(pack.files.keys.where((k) => k.startsWith('rf/')), isEmpty);
      final view = ByteData.sublistView(pack.files['ni']!);
      expect(view.getUint32(0x10, Endian.little), 0);
      expect(
        view.getInt32(0x200, Endian.little),
        -1,
        reason: 'cover shows none',
      );
    });
  });

  group('refuses to build something the device cannot play', () {
    test('no chapters', () {
      expect(
        () => buildDevicePack(chapters: const [], deviceKey: deviceKey),
        throwsA(isA<DevicePackException>()),
      );
    });

    test('audio that is not an MP3 at all', () {
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: Uint8List(500))],
          deviceKey: deviceKey,
        ),
        throwsA(
          isA<DevicePackException>().having(
            (e) => e.message,
            'message',
            contains('MP3 frame'),
          ),
        ),
      );
    });

    test('audio at the wrong sample rate', () {
      // Same header, but the rate field says 24 kHz MPEG-2.
      final wrong = mp3();
      wrong.setRange(0, 4, [0xFF, 0xF3, 0x90, 0xC0]);
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: wrong)],
          deviceKey: deviceKey,
        ),
        throwsA(
          isA<DevicePackException>().having(
            (e) => e.message,
            'message',
            contains('44100Hz mono'),
          ),
        ),
      );
    });

    test('audio in stereo', () {
      final wrong = mp3();
      wrong.setRange(0, 4, [0xFF, 0xFB, 0x90, 0x00]); // stereo
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: wrong)],
          deviceKey: deviceKey,
        ),
        throwsA(isA<DevicePackException>()),
      );
    });

    test('an image that is not 320×240', () {
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: mp3())],
          deviceKey: deviceKey,
          cover: IndexedImage(
            width: 64,
            height: 64,
            pixels: Uint8List(64 * 64),
            palette: const [0],
          ),
        ),
        throwsA(
          isA<DevicePackException>().having(
            (e) => e.message,
            'message',
            contains('320×240'),
          ),
        ),
      );
    });

    test('a device key that is not four words', () {
      expect(
        () => buildDevicePack(
          chapters: [DevicePackChapter(audio: mp3())],
          deviceKey: const [1, 2, 3],
        ),
        throwsA(isA<DevicePackException>()),
      );
    });
  });

  test('the same inputs build the same pack', () {
    expect(build().files['ni'], build().files['ni']);
    expect(build().files['ri'], build().files['ri']);
  });
}

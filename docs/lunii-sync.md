# Syncing straight to a Lunii storyteller

[lunii-export.md](lunii-export.md) writes a STUdio archive that a grown-up then
transfers by hand. This document covers the other half: writing a pack **onto an
attached storyteller directly**, so the share menu can offer "send to the Lunii"
when one is plugged in.

Everything below was verified against a physical FW2 device, not taken on trust
— see [tool/lunii_probe.dart](../tool/lunii_probe.dart), which re-checks every
claim here against whatever device is attached and never opens it for writing.

## The device

A FW2 storyteller mounts as plain **USB mass storage**, FAT32, volume label
`LUNII` (`VID_0483&PID_A341`). No libusb, no driver, no vendor protocol — it is
ordinary file I/O, which is why this can live in pure Dart.

```
<drive>/
├── .md          512 B  device metadata; device key at 0x100
├── .pi          16 B per installed pack — the pack list
├── .cfg         device settings (volume, sleep timer); not ours to touch
├── version      firmware build date, e.g. "2020-11-27 14:51 UTC"
└── .content/
    └── <PACK>/  last 4 bytes of the pack uuid, uppercase hex
        ├── ni   node index — the story graph
        ├── li   list index — action-node options
        ├── ri   resource index — image asset paths
        ├── si   sound index — audio asset paths
        ├── bt   64 B boot file — ties the pack to this device
        ├── nm   empty
        ├── rf/000/XXXXXXXX   images
        └── sf/000/XXXXXXXX   audio
```

`.pi` is a flat run of 16-byte pack uuids. The `.content` directory name is the
**last 4 bytes of that uuid as uppercase hex** — so uuid `…B3941EE8` lives in
`.content/B3941EE8`.

## Ciphering

A modified XXTEA: rounds are `1 + 52/n`, where stock XXTEA uses `6 + 52/n`. At a
full 512-byte block that is exactly one round. Little-endian 32-bit words,
delta `0x9E3779B9`.

**Only the first 512 bytes of a file are ciphered** — one flash sector. The tail
is plaintext, which is why an MP3 on the device still shows readable frame
headers past byte 512.

| File | Ciphered with |
|------|---------------|
| `ri`, `si`, `li`, `rf/*`, `sf/*` | generic key |
| `bt` | device key |
| **`ni`** | **not ciphered** |
| `nm` | empty |

`ni` being plaintext is the trap: it is an index like the others, the
reverse-engineering notes list it among the encrypted files, and deciphering it
silently corrupts the header while leaving the node entries (past byte 512)
looking perfectly valid.

The generic key is the same on every device:

```
0x91BD7A0A, 0xA75440A9, 0xBBD49D6C, 0xE0DCC0E3
```

The **device key** is per-storyteller. Take the 0x100 bytes of `.md` at offset
0x100, decipher with the generic key, then read the first 16 bytes of the result
with its halves swapped — `plain[8:16] + plain[0:8]` — as four little-endian
words. The block length matters: at 0x100 bytes it is 64 words and so runs one
round, and deciphering a shorter slice runs a different number of rounds and
yields a wrong key with no error.

`bt` is then `cipher(ri[0:0x40], deviceKey)` over the **already-ciphered** `ri`,
so deciphering `bt` reproduces the head of `ri` exactly as stored on disk. That
identity is the cheapest way to prove a derived key is correct, and
`lunii_probe` checks it against every pack on the device.

## ni — the story graph

Plaintext. A 512-byte header, then one 44-byte entry per stage node.

| Offset | Size | Field |
|--------|------|-------|
| 0x00 | 2 | format version (1) |
| 0x02 | 2 | pack version (2) |
| 0x04 | 4 | header size (0x200) |
| 0x08 | 4 | node size (0x2C) |
| 0x0C | 4 | stage node count |
| 0x10 | 4 | image count — must equal `ri` entries |
| 0x14 | 4 | sound count — must equal `si` entries |
| 0x18 | 1 | control byte |

Each 44-byte node:

| Offset | Size | Field |
|--------|------|-------|
| 0x00 | 4 | image index, `-1` for none |
| 0x04 | 4 | audio index, `-1` for none |
| 0x08 | 12 | ok transition: list index, option count, option index |
| 0x14 | 12 | home transition, same triple, `-1,-1,-1` for none |
| 0x20 | 10 | five `uint16` flags: wheel, ok, home, pause, autoplay |
| 0x2A | 2 | padding |

`li` is a flat run of `int32` stage-node indices; a node's transition triple
slices into it at *list index* for *count* entries. `ri` and `si` are runs of
12-byte asset paths, `000\XXXXXXXX`, pointing into `rf/000/` and `sf/000/`.

## Asset formats

These are device requirements, not conveniences — both confirmed by decoding
assets off the attached device.

- **Images** — BMP, exactly **320×240**, **4 bpp, BI_RLE4**, with a 16-entry
  palette carried per image.
- **Audio** — **MPEG-1 Layer III, 44.1 kHz, mono**, no ID3 tags.

### Images

From [tool/lunii_image_survey.dart](../tool/lunii_image_survey.dart), which
reads the headers *and* decodes the RLE stream of all **199 images in 9
packs**. Every one agrees:

| | |
|--|--|
| Shape | 320×240, 4 bpp, `BI_RLE4`, bottom-up, 40-byte `BITMAPINFOHEADER` |
| Palette | 16 BGRA entries immediately after the header, pixel data straight after that |
| Sizes | `bfSize` and `biSizeImage` both correct on all 199 |
| Stream | decodes to exactly 320×240 and ends cleanly, all 199 |
| Escapes | end-of-line, absolute, end-of-bitmap — **no delta anywhere** |
| Longest run | 255 px, the format's maximum |

**The palette is per image, and it is not greyscale.** Only 149 of the 199 are
grey, and even those are not a fixed 16-level ramp — each file carries its own
unordered, unevenly spaced palette, the signature of a quantiser
(`0x00 0x66 0xff 0x3c 0xea …`). The remaining 50 are colour. So an encoder is
free to choose its own 16 colours; nothing has to be flattened to grey.

Two things follow for the encoder. Runs cap at 255 px. And since no image on
the device uses RLE4's delta escape, the firmware's support for it is
unproven — emit runs, absolute, end-of-line and end-of-bitmap only.

Every stream also ends `00 00 00 01`: an end-of-line for the final row and
then end-of-bitmap. `ffmpeg` grumbles at that ("ended frame decode with 2
bytes left over") — and grumbles identically at the device's own files, so it
is the convention here rather than a defect.

#### Producing it

[lib/adapters/image/bmp_rle4.dart](../lib/adapters/image/bmp_rle4.dart)
encodes and decodes this. The decoder earns its place twice over: it is how
the survey reads the device, and running all 199 device images through
decode → encode → decode returns identical pixels every time, at 98% of their
original size. That is the strongest check available short of writing to the
device.

[cover_image.dart](../lib/adapters/export/cover_image.dart) is the producer.
Its palette is chosen rather than computed — ten steps of sky, four of moon,
two of star — because we drew the picture and know what is in it. The ten sky
steps would band across 240 rows, so the reduction is ordered-dithered against
a 4×4 Bayer matrix, which suits RLE4 nicely: a dither alternates between two
indices and an RLE4 run *is* two alternating nibbles, so it costs almost
nothing to store. The night sky comes to 15.9 kB against 230 kB for the same
picture at 24-bit, with all sixteen entries in use.

### The picture a story wears

Three producers, tried in this order, each a fallback for the one before:

1. **A portrait drawn for the story.**
   [lunii_portrait.dart](../lib/adapters/export/lunii_portrait.dart) reduces a
   picture the image model drew — head and shoulders of one character, against
   a flat background, asked for in those terms by `luniiPicturePrompt` because
   a *scene* at 320×240 in sixteen colours is a smudge with weather in it.
   `IllustrationService.ensureLuniiPortrait` draws it once and keeps it, with
   that character's reference sheet attached so the device shows the same
   animal the story does.
2. **The world's procedural picture**, seeded on the world's name.
3. **A motif**, for a story that belongs to no world.

Who the portrait is of comes from `portraitSubject`, hashed from the story's
id over the characters that story actually mentions: different between
episodes, identical every time for one episode. That is the point of the whole
arrangement — before it, every episode of a world wore the same picture, so a
shelf of six Pip stories was six identical packs.

The reduction is crop-then-scale (squeezing a 3:4 cover into 4:3 stretches a
face), a contrast and saturation lift *before* quantisation, then median cut to
sixteen colours over the pixels that exist rather than a fixed palette — a sea
story and a forest story want different sixteen. Measured on five real
portraits with [tool/lunii_portrait_check.dart](../tool/lunii_portrait_check.dart):
all sixteen entries used, mean palette distance 5 200–12 000, largest single
colour 25–47% of the frame, 14–31 kB as RLE4.

**Two traps, both found by running it against the real library rather than
fixtures.** The first version called `decodePng` — but the image model returns
**JPEG**, and the picture store names every file `.png` because that is what it
was written to hold. Every real picture decoded to null, nothing threw, and the
device silently kept showing the procedural cover. It sniffs the format now.
The second: a redraw saved a row without removing the stale one, so a story
ended up with two device pictures and the reader picked one at random — the
same accumulate-rather-than-replace bug the chapter pictures already had fixed.

### Audio

From [tool/lunii_audio_survey.dart](../tool/lunii_audio_survey.dart),
which walks every frame of every sound on an attached device. On the FW2
device here that is **1,867,061 frames across 375 sounds in 9 packs**, and the
result is completely uniform:

| | |
|--|--|
| Format | MPEG-1 Layer III, 44100 Hz, mono — **every frame**, no exceptions |
| Bitrate | **VBR**, 32–320 kbps; most common 80, mean 90 |
| Tag | Xing/LAME on all 375; no ID3 on any |
| Layout | audio starts at byte 0; frame walk consumes each file exactly |

So sample rate, layer and channel mode are hard requirements and bitrate is
not — the device happily plays anything from 32 to 320 kbps.

**Read the whole stream, not the first frame.** These files are VBR and a VBR
file opens with a Xing tag frame whose bitrate describes the tag, not the
audio. A first-frame-only survey of this device reports a confident, wrong
"128 kbps CBR". Sample rate, layer and mode *are* safe to read from frame one;
bitrate is not.

#### Producing it

[lib/adapters/audio/mp3_encoder.dart](../lib/adapters/audio/mp3_encoder.dart)
encodes to **128 kbps CBR** — inside the range the device demonstrably plays,
constant so there is one less variable in an embedded decoder, and carrying the
same leading LAME tag the device's own files have. A minute of narration is
960 kB, against about 670 kB had we matched the device's own VBR.

Of the app's voices only ElevenLabs (`mp3_44100_128`) already conforms. Gemini
and the Windows voice produce 24 kHz WAV, which goes straight through the
encoder: LAME resamples 24 kHz → 44.1 kHz and downmixes in the same pass, at
roughly 60× realtime. **OpenAI's 24 kHz MP3 is not handled yet** — it has to be
decoded first, and while the vendored DLL does export mpglib's `hip_decode*`,
that path is not built.

Encoding is native, via LAME vendored at
[windows/third_party/lame/](../windows/third_party/lame/README.md) and bound over FFI
in [lib/adapters/audio/lame.dart](../lib/adapters/audio/lame.dart). It is
Windows-only for now; `canEncodeMp3` is false elsewhere, and a caller that
finds it false should offer the STUdio zip instead.

## Building a pack

[lib/adapters/lunii/device_pack.dart](../lib/adapters/lunii/device_pack.dart)
assembles the tree above from a story's chapters. It **returns the files, it
does not write them** — a pack is a value that can be inspected, asserted over
and diffed long before anyone decides where to put it, and nothing in the
builder can reach a device by accident.

It is the last place a format mistake can be caught cheaply, so it refuses
audio that is not MPEG-1 Layer III 44.1 kHz mono and images that are not
320×240. Past that point the bytes are ciphered, on a device, and silent.

`test/adapters/device_pack_test.dart` runs the probe's own assertions inward:
the indexes decipher into `000\XXXXXXXX` paths, `bt` reproduces the head of
`ri` byte for byte, `ni` is plaintext with counts agreeing with `ri` and `si`,
and following the list index from the cover walks every chapter exactly once.

### Two things the device has now settled

Neither could be answered from the nine packs on hand, so both were guesses
made as conservatively as possible. A six-chapter story played start to finish
on the FW2 device on 2026-08-09, which answers both:

- **A cover node with no audio works.** Every pack that shipped with the
  device plays a title jingle from node 0; a generated story has none, so its
  cover node carries `audio = -1`. The firmware is fine with it.
- **`bt` padded because `ri` is short works.** `bt` is a fixed 64 bytes from
  the head of `ri`. Every shipped pack has at least six images so its `ri` is
  comfortably longer, while a story whose chapters share one cover has a
  12-byte `ri` and the builder zero-pads the rest. The device accepts it.

What is *not* settled is whether a silent cover is a good idea. The device
navigates by ear — a child too young to read picks a pack by listening to it
announce itself — so a pack that says nothing is hard to find. That is a
product gap, not a format one; see the open items in
[decision-log.md](decision-log.md).

## Navigating by ear

The storyteller has no screen worth reading, so a pack that is silent until a
chapter starts leaves a child with no idea which story they are standing on.
The cover node therefore speaks the story's name.

Mechanically it is one more sound asset. The spoken title is **sound 0**, which
shifts every chapter along by one — that shift is the thing to be careful
about, and `device_pack_test.dart` pins it: a pack whose chapter 1 plays the
title and whose last chapter plays nothing is the bug to avoid. The end node
says the title again, so the story audibly comes to rest where it began.

The clip is synthesized by the app's own voice and cached like any narration —
so it costs one short request per story, once. It is **best effort**: a voice
that refuses (no key, quota spent) leaves the cover silent, which is how every
pack written before this behaved. A nicety must not fail a transfer.
`tool/lunii_write.dart` never calls a provider itself; it reports
`Cover: silent (no spoken title cached)` when the clip is not on disk.

### A world's own picture

The night-sky cover varies only where its stars fall, so two worlds arrived on
the device looking identical — same indigo, same moon in the same corner. On a
device with no screen worth reading, the picture is half of how a child tells
one pack from another.

[world_cover.dart](../lib/adapters/export/world_cover.dart) derives everything
from the world's **name**: one of eight palettes, one of six horizons, one of
five things in the sky. So every episode of a world shows the same place, two
worlds are near-certain to look nothing alike, and a world's picture never
changes as long as it is called what it is called — the name is hashed with
FNV-1a rather than `String.hashCode`, which is not stable across runs.

Sixteen colours cannot make a smooth sky, so the gradient is ordered-dithered;
without it the sky is ten visible stripes. Only a **standalone** story still
asks which picture to use.

### Still to build: a spoken chapter menu

The cover already has `wheel: true`, but its transition has `count: 1`, so
turning the wheel does nothing. A real menu needs a transition spanning N list
entries and one short "announce" node per chapter — *"Chapter two: The Moon
Silk Mystery"* — that the wheel scrolls, with OK dropping into the chapter.

Before building it, run `tool/lunii_node_survey.dart` against an attached
device and copy the shape off the packs that work. The history in
`device_pack.dart` is the argument: the first pack written to hardware guessed
what a story's last node should look like, played every chapter, and then threw
an error screen.

## Writing safely

The nine packs already on a device are purchased content, and a botched `.pi`
is what loses them. So
[lib/adapters/lunii/device_writer.dart](../lib/adapters/lunii/device_writer.dart):

- Refuses anything that does not look like a storyteller, and re-derives the
  device key and checks it against an installed pack's `bt` before writing
  with it.
- Copies `.pi` and `.md` aside before touching a byte.
- Writes the new `.content/<PACK>/` tree fully, reading each file back, and
  only then appends the uuid to `.pi` — a half-written pack that is not listed
  is invisible, whereas a listed pack that is half-written is not.
- Never opens `.cfg`.

Snapshot with [tool/lunii_manifest.dart](../tool/lunii_manifest.dart) either
side of the write. It exits non-zero if anything changed that shouldn't have.

**`.pi` must be appended to, not rewritten.** Every file at the root of a
storyteller carries the Hidden attribute, and Windows refuses the
`CREATE_ALWAYS` that `File.writeAsBytes` uses on a hidden file — "Access is
denied", at the very last step, after the whole content tree is already on
disk. Opening the existing file to append is fine, and it is the better
semantic anyway: the ids already there are never read into memory and written
back, so no bug in this code can scramble them.

### The first write

Done, on the FW2 device here, 2026-08-09: three chapters of real narration
from the app's cache, re-encoded, with the night-sky cover.

```
Wrote 11 files. 9 packs → 10
```

`lunii_manifest diff` over the whole volume, before and after:

```
added: 10   (all under .content/CE4D1B54/)
removed: 0
changed: 1  (~ /.pi)
OK — 10 new file(s), .pi appended; nothing else touched.
```

`lunii_probe` then passes on the new pack exactly as it does on Lunii's own:
device key verified across all ten, `hdr=512 node=44 nodes=4 img=1/1 snd=3/3`,
every list entry in range.

**That first pack played its chapters and then threw an error screen** — its
last chapter had no onward transition, and autoplay followed it into `-1`. The
fix and the survey behind it are described under the node graph above. The
second attempt, a six-chapter story, played start to finish.

An attempt that fails partway leaves a directory `.pi` does not list. The
device cannot see it, and
[tool/lunii_remove_orphan.dart](../tool/lunii_remove_orphan.dart) clears it —
refusing, always, to remove anything `.pi` does list.

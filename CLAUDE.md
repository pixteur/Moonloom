# CLAUDE.md

Guidance for Claude and other coding agents working in this repository.

## Project snapshot

- `MoonloomApp` is a Flutter-first bedtime storytelling app for children.
- The current repo is mostly pure Dart/Flutter application code plus the generated Windows runner.
- There is no custom native iOS/macOS layer yet, and there is no app-specific C++ portability problem yet.
- As of now, the repo has `windows/` only. There is no `ios/` or `macos/` directory yet.

## Architecture constraints

- Keep the domain layer pure Dart.
- Keep platform logic in thin adapters.
- Do not leak provider-specific or Apple-specific logic into `lib/domain/`.
- Preserve the current design direction from [docs/architecture.md](docs/architecture.md): UI/layout changes live in Flutter, platform-specific work lives in adapters and platform scaffolding.

## iOS / App Store strategy

### Important framing

For this repo, iOS is primarily a Flutter platform-expansion and App Store compliance task, not a native rewrite.

The first iOS milestone should be:

1. Add Apple platform scaffolding on a Mac:
   - `flutter create --platforms=ios,macos .`
2. Configure signing, bundle ID, app name, icons, versioning, and device targets in Xcode.
3. Implement Apple-specific adapters:
   - `SecretStore` via Keychain
   - iOS TTS/STT adapter(s)
   - microphone permission strings
   - safe-area and touch verification
4. Validate on simulator and physical devices.
5. Ship to TestFlight before App Store submission.

### Repo-specific product risk

The app concept is child-focused, AI-backed, and privacy-sensitive. Any iOS work must consider App Store review constraints up front.

### Kids Category decision

This product is currently positioned like a kids app. That makes one early decision especially important:

- either ship in the `Kids Category`
- or ship as a parent/family app that is about children but not marketed as primarily for kids

Current messaging in [README.md](README.md) strongly points toward a kids-facing product, so assume Kids Category constraints unless product direction changes.

### If shipping in the Kids Category

Treat the following as baseline requirements:

- Parent-only settings must be behind a parental gate.
- External links, purchases, and provider-key setup should be parent-gated.
- Avoid third-party analytics and third-party advertising.
- Be conservative with any outbound data sharing involving child profiles or story content.
- Age band, privacy disclosures, and review notes must be prepared carefully.

### AI-provider rules for this app

The plan in [docs/ai-providers.md](docs/ai-providers.md) sends prompts and profile-derived context to third-party AI providers. On iOS, that means:

- clearly disclose that data may be sent to third-party AI providers
- obtain explicit parent/user permission before sharing personal data with third-party AI
- keep the child profile and prompt payload as minimal as possible
- keep provider configuration in a parent-only area

Do not casually add telemetry, logging, or debugging uploads that include story text, profile text, or prompts.

### Account and billing implications

- If the app later supports real cloud accounts, account deletion must be initiable in-app.
- If the app later moves from BYO-key to a hosted paid story service consumed in the app, expect In-App Purchase requirements to apply.

## Recommended launch sequence

Prefer this order unless product strategy changes:

### Version 1

- local-only child profiles
- no cloud account system
- BYO AI provider key in a parent-only area
- no third-party analytics or ads
- TestFlight-first rollout

### Version 2

- hosted backend
- optional sync/accounts
- subscription / billing work

## Files to update when iOS work starts

- [build-plan/phase-5-polish-port.md](build-plan/phase-5-polish-port.md)
- [docs/decision-log.md](docs/decision-log.md)
- [docs/ai-providers.md](docs/ai-providers.md)
- [docs/safety.md](docs/safety.md)
- [README.md](README.md)

## Traps that have already cost time

Read these before touching the areas they describe. Each one shipped a bug
that only surfaced on a real device.

**Migrations: never reuse a schema version another branch has used.** Every
branch on a dev machine shares one database in the documents folder. A branch
that stamps a version another branch hasn't reached means `onUpgrade` never
fires for the skipped step — `from == to`, so the callback is skipped
entirely — and the column is silently never added. It surfaces far away as a
null-check crash when drift maps a row, or "no such column" on save. Guard
each step with `_addColumnIfMissing`, and note `beforeOpen` reconciles missing
columns regardless of version. **In-memory tests cannot catch this**: they go
through `onCreate` and always get every column.

**Anything a voice reads is spoken literally.** Markup is not skipped — an
asterisk, a bracketed gloss, a language tag, an unrecognised audio tag all get
read out to a child, character by character. Narration direction therefore
never enters `story_text`; it travels as structured cues and each adapter
renders it. See [docs/narration-cues.md](docs/narration-cues.md).

**Playback is chunked, and the reader is not.** The voice provider is given a
few sizeable chunks so one chunk's playback outlasts the next one's synthesis.
Position is reported *per clip*, so anything mapping progress across a whole
chapter must scale it. Cache keys are per chunk **with the narration cue mixed
in** — never build one by hand. `chapterAudioKeys` in `narrated_chunks.dart` is
the only place that maps a chapter to its cache entries; ask it. This already
cost us once: the exports keyed on the whole chapter text, so fully downloaded
stories exported as "no narration saved yet", and it hid for weeks because a
chapter *without* cues is a single chunk whose key happens to be identical —
so the demo story and every cue-less test passed. `tool/export_keys_check.dart`
re-checks it against the real library.

**An MP3's first frame does not describe the file.** A VBR file opens with a
Xing tag frame, and that frame's bitrate describes the tag, not the audio
behind it. Surveying a Lunii's own sounds one-frame-deep reports a confident
"128 kbps CBR"; walking all 1.87M frames shows VBR from 32 to 320. Sample
rate, layer and channel mode *are* safe to read from frame one — bitrate is
not. Same shape as the migration trap: a plausible answer, no error, wrong.

**Every file at a storyteller's root is Hidden, so `.pi` must be appended to,
not rewritten.** Windows refuses the `CREATE_ALWAYS` that `File.writeAsBytes`
uses on a hidden file. It fails at the *last* step of a device write, after
the whole content tree is on disk — and because `.pi` goes last by design, the
half-done pack was invisible and the device was unharmed. Open the file and
append; it is also the safer semantic, since the existing pack ids are then
never rewritten at all.

**A model that answers your endpoint is not a model that does your job.**
Google's image, music, robotics and computer-use models all respond to
`generateContent`, so a story-model list built from that alone offered a music
generator — and, because "pro" was in its name, called it "best prose". Mocked
responses cannot catch this; they only contain what you already believed.
`tool/model_catalog_probe.dart` asks the real APIs with the saved keys. Same
shape as the others here: a plausible answer, no error, wrong.

**Narration is keyed by the voice that spoke it, so changing voice looks
exactly like data loss.** Nothing is deleted — 600 MB of it sat on disk — but
the app stops asking for it, every download badge reverts to a cloud, and a
grown-up reports the audio as missing. Anything that only needs *a* recording
(the badge, the exports, the storyteller) goes through
`domain/saved_narration.dart`, which tries the current voice and then every
voice this device has used. Playback is the exception: a story is read in the
voice that was chosen. `tool/narration_voices.dart` shows which voice actually
holds each story.

**The image model returns JPEG, and every picture file is named `.png`.**
The store names files for what it was written to hold; the model sends what it
likes. A reducer built on `decodePng` therefore returned null for every real
picture in the library — no throw, no log, the Lunii just kept showing the old
procedural cover. Sniff the format (`img.decodeImage`), never assume it from
the name. Fixtures cannot catch this: a test writes the PNG it then reads.

**The AI provider is `fake` until settings load, and fake does not fail.**
`aiConfigProvider` must answer synchronously, so it answers `fake` and loads
the real choice behind it. An engine read in that window writes canned
chapters *successfully* — no fallback warning, never named, six chapters of
"The gentle path home and a peaceful goodnight." Take the engine through
`readyStoryEngine(ref)`, never `ref.read(storyEngineProvider)`. A probe that
builds `GeminiProvider` directly cannot reproduce this; it skips the race.

**The full narration polish is not safe to run twice.** A second pass
lengthened 68 of 561 real files by up to 15 s: levelling moves room tone across
the silence floor, so a sentence break becomes a paragraph break. New audio is
polished once, on the way in. Anything going back over the cache uses
`deClickNarration`, which is idempotent — `tool/polish_cache.dart` checks and
reports this on every run, and backs files up before rewriting them.

**Gemini's WAVs end with a C2PA manifest — never read "everything after
byte 44" as sound.** Every 3.8 voice reply carries a `C2PA` chunk after its
`data`: ~6 KB of signed Content Credentials. The polish read samples by
position, played the manifest as ~126 ms of loud noise and saved it that way —
the "pop of static at the end of paragraphs" and in the Lunii navigation. Two
earlier fixes (gain clipping, a de-click) were real but aimed beside it. 3.8
also returns a *complete WAV* even from `generateContent`, so wrapping its
reply in another header nests one WAV inside another. Anything that reads
samples by position goes through `plainWav` (adapters/audio/wav.dart) first;
`tool/strip_c2pa.dart` repairs narration saved before, `tool/c2pa_scan.dart`
finds it. Found by reading the chunk list, after the user said "it's how we
are reading it" — the shape of every trap here: plausible, no error, wrong.

**Verify against the real database or device, not just tests.** Both the
migration bug and the download-badge bug passed every test and failed
immediately in the app. `tool/` holds read-only probes for exactly this.
An independent decoder counts as verification too — `ffprobe` confirmed the
MP3 encoder's output rather than the app's own parser vouching for itself.

## Current state

Beyond the phase docs, these are live and verified on hardware:

- **Story quality** — every chapter gets an editorial second pass before it is
  saved or spoken; per-chapter titles. [docs/story-quality.md](docs/story-quality.md)
- **Narration cues** — the pass also writes direction for the voice; chunking
  splits only where the feeling changes. [docs/narration-cues.md](docs/narration-cues.md)
- **Lunii** — the FW2 format is fully reverse-validated against a physical
  device; the STUdio zip export ships. Audio and images encode to what the
  device takes (LAME over FFI for MP3, Windows only; RLE4 BMP in pure Dart),
  `device_pack.dart` assembles a pack and `device_writer.dart` installs one.
  **Confirmed end to end on real hardware**: a six-chapter story writes,
  passes `lunii_manifest` (nothing else touched) and `lunii_probe`, and plays
  start to finish on the device. "Send to the Lunii" is in the parent-only
  share menu. The device navigates by ear, so the cover speaks the story's
  title — sound 0, which shifts every chapter along one. A spoken chapter menu
  is the next thing it needs, and wants a `lunii_node_survey` against an
  attached device first rather than a guess at the shape. Each story now wears
  a portrait of one of its own characters rather than its world's picture, so
  a shelf of episodes is no longer six identical packs.
  [docs/lunii-sync.md](docs/lunii-sync.md)
- **Deferred** — [docs/plan-competing-llms.md](docs/plan-competing-llms.md)

`tool/` holds read-only diagnostics: `lunii_probe` (re-checks the crypto
against an attached device), `lunii_audio_survey` and `lunii_image_survey`
(what format the device's own assets actually are — both decode the whole
stream, not just headers), `lunii_manifest` (proves a write touched only what
it should), `db_schema` / `columns_check` (what the on-disk database actually
has), `refine_diff` and `cue_report`.

`lunii_node_survey` reports how the packs on a device wire their story graphs;
`audio_cache_audit` finds cached narration a voice provider got wrong;
`lunii_portrait_check` draws real portraits and reduces them to the device's
screen, writing both sizes out to look at — whether a face is readable at
320×240 in sixteen colours is not something an assertion can judge.

Three `tool/` scripts do write: `lunii_write` (dry run unless `--write`),
`lunii_remove_orphan` (refuses anything `.pi` lists) and `audio_cache_audit`
(read-only unless `--delete`). Snapshot with `lunii_manifest` either side of
using the first two.

## Before committing

CI runs `dart format --output=none --set-exit-if-changed .` **before** analyze
and tests, so an unformatted file fails the whole job on whitespace. Enable the
shared hook once per clone: `git config core.hooksPath .githooks`.

## Reference docs

- Flutter iOS setup: <https://docs.flutter.dev/platform-integration/ios/setup>
- Flutter iOS release: <https://docs.flutter.dev/deployment/ios>
- Apple App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
- Apple Kids guidance: <https://developer.apple.com/kids/>
- Apple App privacy details: <https://developer.apple.com/app-store/app-privacy-details/>
- Apple account deletion requirement: <https://developer.apple.com/support/offering-account-deletion-in-your-app/>
- App Store Connect uploads: <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/>

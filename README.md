# MoonloomApp

A kids' nighttime storytelling app. Each night you **seed a story**, then **roll the dice** or pick from **6 openings dealt at random from a ~50-card deck**, and the app uses an AI model (Claude / OpenAI / Gemini) to invent the next chapter on the spot — read aloud in an expressive character voice.

Built **Flutter-first for PC (Windows)**, designed to port cleanly to **macOS and iOS** from a single codebase.

---

## What it does

- **Per-child accounts** (multi-kid) with an onboarding quiz — including stories they already love — that seeds each kid's story world.
- **Nightly launch choices:** 🎲 *Roll the dice* for a new twist, ▶️ *Continue where we left off*, or ⌨️/🎤 *Tell it what to hear* (text or microphone).
- **Multiple story series + branching** — keep several sagas going, or branch off a brand-new one (pick a **theme** and who the hero is).
- **~16 story themes, blend up to 3** — Adventure, Mystery, Superhero, Cozy/Dreamtime, Mindfulness, Feelings & Kindness, Slice-of-Life, Nature, Technical, Documentary, Learning, History, Around the World, Fairytale, Silly, Surprise — plus a **Custom** free-text flavor. Pick one to lead and up to two more to colour it.
- **Stories name themselves** — leave the title blank and the AI titles it from what actually happened.
- **Bilingual mode** — toggle on *any* story to weave in a second language and soak it up at bedtime.
- **Story archive** — browse past episodes with short recaps and replay any of them aloud.
- **Adjustable detail levels** and **streaming** stories that appear as they're written.
- **Grows with your kid** — a settings page to tune details, age, and tone, plus a **learned profile** that adapts from how they play.
- **Age-appropriate & safe** — hard age-rating constraints, a parent **banned-themes** list, an optional **Parent's Brief** for values/tone, and a content guardrail (with a second-model reviewer on by default).
- **New Interests** — add a fresh fascination (fractals, Jupiter, dinosaurs…) and the app nudges future stories that way.
- **Voice story reader** — male/female expressive voices that take on each character's personality, in multiple languages.
- **Multi-language** — English, French, Spanish at launch; Japanese and more built into the framework.
- **Personalizable UI** — kid-friendly, touch-ready, with color/theme customization.

## Status

🟢 **Runnable on Windows**, with the full nightly loop working end to end:

- Per-child profiles + onboarding quiz; safety guard + banned themes.
- Story engine with real AI (Claude / ChatGPT / Gemini) behind a parent-gated, consent-disclosed key screen (keys secured via Windows DPAPI).
- **Voice reader** — natural cloud voices (Gemini / OpenAI / ElevenLabs) or free on-device TTS. Narration is **cached on device** for instant, gap-free replays.
- **Bookshelf → Worlds → Episodes → Characters** — a loved world (e.g. "Bob and Leo") spawns endless consistent episodes. A grown-up tunes the world (premise, themes, cast) behind **Edit world**; adding a character introduces them in the next story, and removing one gives them a warm on-the-page goodbye rather than silently deleting them.
- **Read-along** — text auto-scrolls and highlights the word being read.
- **`.sleepy` files** — export/import a story (text + audio) as one shareable file.
- **Export a story out of the app** — a single-file **audiobook** for a phone or car, or a **Lunii story pack** for the screen-free storyteller box (see [docs/lunii-export.md](docs/lunii-export.md)).
- **Parent mode** — grown-up controls (delete/rename/edit) are hidden by default so kids can't change things, and every deletion needs the parent gate plus a two-step confirmation.
- **One settings page** — parent mode, story AI, and voice on a single scroll.

~80 tests pass; CI (format + analyze + test) green on `main`. App icon: [app_icon.png](app_icon.png) / [app_icon.svg](app_icon.svg) (a sleeping crescent moon).

## Key decisions (locked)

| Area | Choice |
|------|--------|
| UI framework | **Flutter** (Windows → macOS → iOS, one codebase) |
| AI compute | **Multi-provider BYO-key** — Claude (default), ChatGPT, and Gemini, behind a parent-gated, consent-disclosed key screen; keys secured via Windows DPAPI. Abstraction can switch to a **hosted backend** later |
| Data | **Local-only on device** (privacy / COPPA-first); optional cloud sync later |
| Voice | **Pluggable TTS** — on-device for free/offline, cloud (e.g. ElevenLabs/Azure) for premium character voices |

## Documentation

- [docs/](docs/) — architecture, safety, data model, AI providers, voice, i18n, UI/UX, storage layout, and a running decision log.
- [CLAUDE.md](CLAUDE.md) — repo guidance for Claude/coding agents, including iOS/App Store constraints.

_(The phased internal roadmap under `build-plan/` is kept local and is git-ignored.)_

## Getting started (dev)

**Prerequisites**

- **Flutter 3.44+** with the Dart SDK (this repo uses Dart 3.12). `flutter doctor` should be clean for the Windows desktop toolchain (Visual Studio with "Desktop development with C++").
- **Windows Developer Mode ON** — Settings → For developers (needed for plugin symlinks).
- On Windows, `flutter_tts` builds against **NuGet**; if the build complains, put `nuget.exe` on your PATH (e.g. in your Flutter `bin` folder).

**Run**

```powershell
git clone https://github.com/pixteur/MoonloomApp.git
cd MoonloomApp
flutter pub get           # install dependencies
flutter run -d windows    # run the desktop app (opens portrait, phone-sized)
```

Or build a debug exe and launch it directly:

```powershell
flutter build windows --debug
.\build\windows\x64\runner\Debug\moonloom.exe
```

**Configure AI + voice (in-app):** open the ⚙️ grown-up settings (parental gate) → add a provider API key + consent (Claude/OpenAI/Gemini) → scroll down to the Voice section to pick a cloud voice. Keys are stored securely on-device (DPAPI); nothing is sent until you add a key and consent.

**Tests / checks**

```powershell
dart format .            # format
flutter analyze          # static analysis (CI-gated)
flutter test             # unit/widget tests
```

**Generated code:** Drift `*.g.dart` files are committed. After changing tables/schema, regenerate:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

**Where data lives:** on-device only — SQLite DB + a `Moonloom/` story library (audio, `.sleepy` exports) under your Documents folder. See [docs/storage-layout.md](docs/storage-layout.md).

## Windows installer (MSIX)

Build a double-click installer:

```powershell
pwsh scripts/build_windows_installer.ps1
# → build\windows\x64\runner\Release\moonloom.msix
```

The script does a release build, generates the MSIX manifest (`dart run msix:build`),
and packs with the **Windows SDK's** `makeappx.exe`. (We use the SDK packer because
the `msix` package's bundled one can fail with a "side-by-side configuration is
incorrect" error. Where that packer is healthy, plain `dart run msix:create` also
works.) Installer settings live under `msix_config` in `pubspec.yaml`.

**Installing the .msix:** it must be **signed** and the signing cert **trusted**,
or Windows won't install it:

1. Create a self-signed cert (once) and export the public cert:
   ```powershell
   $c = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Pixteur" -CertStoreLocation Cert:\CurrentUser\My
   Export-Certificate -Cert $c -FilePath moonloom.cer
   ```
   Make sure `msix_config.publisher` in `pubspec.yaml` matches the cert subject
   (`CN=Pixteur`), then rebuild.
2. Sign the package with the Windows SDK's `signtool.exe` (found under
   `C:\Program Files (x86)\Windows Kits\10\bin\<ver>\x64\`):
   ```powershell
   signtool.exe sign /fd SHA256 /a build\windows\x64\runner\Release\moonloom.msix
   ```
   (`/a` auto-selects your cert; or use `/f cert.pfx /p <password>`.)
3. On the target PC, import `moonloom.cer` into **Local Machine → Trusted People**,
   then double-click the `.msix` to install.

For release, use a real **EV/OV code-signing certificate** or ship via the
**Microsoft Store** (MSIX is Store-native). Full details — plus the macOS `.dmg`
path (needs a Mac + Apple Developer ID notarization) and `flutter_distributor` —
are in [docs/distribution.md](docs/distribution.md).

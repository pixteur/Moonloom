/// The prebuilt voices, under names a child can choose between.
///
/// Every engine names its voices after something arbitrary — Kore, Puck,
/// Zubenelgenubi — which tells a six-year-old nothing at all. But the friendly
/// names here are not invented out of the air either: each one is chosen to
/// match the characteristic **Google publishes** for that voice, and that
/// characteristic travels with it so a grown-up can see what it is based on.
/// "Whisper" is Enceladus because Enceladus is documented as breathy, not
/// because it sounded that way to me.
///
/// The stored value is always the engine's own id. A friendly name is a label
/// and nothing more: cache keys, settings and every saved recording continue
/// to key on `Kore`, so renaming a label can never orphan audio.
///
/// Order is deliberate — the voices suited to being read to at bedtime come
/// first, because the first six are the ones anybody will actually try.
/// See `docs/voice-tts.md`.
library;

/// One voice: what the API calls it, what a child sees, and the word Google
/// uses to describe it.
class VoiceChoice {
  const VoiceChoice(this.id, this.label, this.character);

  /// The engine's own name, and the only thing ever stored.
  final String id;

  /// What the picker shows.
  final String label;

  /// Google's published characteristic for this voice.
  final String character;
}

/// Gemini's thirty prebuilt voices, bedtime-suited first.
const List<VoiceChoice> geminiVoices = [
  // ── Made for being read to ────────────────────────────────────
  VoiceChoice('Sulafat', 'Honey', 'warm'),
  VoiceChoice('Vindemiatrix', 'Willow', 'gentle'),
  VoiceChoice('Achernar', 'Feather', 'soft'),
  VoiceChoice('Achird', 'Sunny', 'friendly'),
  VoiceChoice('Callirrhoe', 'Meadow', 'easy-going'),
  VoiceChoice('Aoede', 'Breeze', 'breezy'),
  VoiceChoice('Enceladus', 'Whisper', 'breathy'),
  VoiceChoice('Schedar', 'River', 'even'),
  VoiceChoice('Gacrux', 'Old Oak', 'mature'),
  VoiceChoice('Umbriel', 'Drift', 'easy-going'),

  // ── Livelier, for an adventure ────────────────────────────────
  VoiceChoice('Puck', 'Bounce', 'upbeat'),
  VoiceChoice('Zephyr', 'Sparkle', 'bright'),
  VoiceChoice('Leda', 'Sprout', 'youthful'),
  VoiceChoice('Sadachbia', 'Zip', 'lively'),
  VoiceChoice('Laomedeia', 'Skip', 'upbeat'),
  VoiceChoice('Fenrir', 'Rocket', 'excitable'),
  VoiceChoice('Autonoe', 'Dawn', 'bright'),
  VoiceChoice('Pulcherrima', 'Dash', 'forward'),

  // ── Smooth and clear ──────────────────────────────────────────
  VoiceChoice('Algieba', 'Silk', 'smooth'),
  VoiceChoice('Despina', 'Velvet', 'smooth'),
  VoiceChoice('Iapetus', 'Bell', 'clear'),
  VoiceChoice('Erinome', 'Chime', 'clear'),
  VoiceChoice('Zubenelgenubi', 'Buddy', 'casual'),

  // ── Steadier, for a story with a captain in it ────────────────
  VoiceChoice('Kore', 'Captain', 'firm'),
  VoiceChoice('Alnilam', 'Anchor', 'firm'),
  VoiceChoice('Orus', 'Ranger', 'firm'),
  VoiceChoice('Algenib', 'Boulder', 'gravelly'),
  VoiceChoice('Charon', 'Professor', 'informative'),
  VoiceChoice('Rasalgethi', 'Scholar', 'informative'),
  VoiceChoice('Sadaltager', 'Sage', 'knowledgeable'),
];

/// The label for a voice id, falling back to the id itself for an engine whose
/// voices are not catalogued (OpenAI's, or an ElevenLabs id).
String voiceLabel(String id) {
  for (final v in geminiVoices) {
    if (v.id == id) return v.label;
  }
  return id;
}

/// Google's characteristic for a voice id, or empty when unknown.
String voiceCharacter(String id) {
  for (final v in geminiVoices) {
    if (v.id == id) return v.character;
  }
  return '';
}

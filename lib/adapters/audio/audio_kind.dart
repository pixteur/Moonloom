/// What a piece of cached audio actually is.
///
/// The cache stores whatever the voice provider returned and records nothing
/// about its format: Gemini answers with WAV, ElevenLabs and OpenAI with MP3.
/// For a long time that was safe to ignore, because the only audio ever played
/// came from the synthesizer that was live at the time, so asking *it* what it
/// returns gave the right answer.
///
/// It stops being safe the moment a recording outlives the voice that made it
/// — which is the normal case, since narration is kept and voices change. A
/// WAV header announced as MP3 does not play, and the failure is silent.
///
/// RIFF's magic is the tell, and it is the same test `sleepy_service` has
/// always used to decide how to decode a chapter for export. One home for it,
/// so the exporter and the player can never disagree about the same bytes.
library;

import 'dart:typed_data';

/// Whether these bytes are a RIFF/WAVE file.
bool isWavBytes(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x52 && // R
    bytes[1] == 0x49 && // I
    bytes[2] == 0x46 && // F
    bytes[3] == 0x46; //  F

/// The media type to hand a player for these bytes.
///
/// Anything that is not RIFF is treated as MPEG audio, which is what every
/// provider that does not return WAV returns. A wrong guess here is inaudible
/// rather than loud, so the test is on the format we can prove.
String audioMimeOf(Uint8List bytes) =>
    isWavBytes(bytes) ? 'audio/wav' : 'audio/mpeg';

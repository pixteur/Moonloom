/// Who else's work is in here.
///
/// Not decoration: LAME is LGPL, and its licence asks for an acknowledgement
/// and a link to the project in return for shipping the encoder. The app
/// bundles `libmp3lame.dll` to make the 44.1 kHz mono MP3 a Lunii storyteller
/// plays, so the obligation is real and this is where it is met.
///
/// The full licence text ships too, next to the executable under
/// `licenses/lame/`; see `windows/third_party/lame/README.md`.
library;

import 'package:flutter/material.dart';

import '../../adapters/audio/mp3_encoder.dart';

/// One credit: what it is, and what it is used for.
class Credit {
  const Credit({
    required this.name,
    required this.licence,
    required this.url,
    required this.used,
  });

  final String name;
  final String licence;
  final String url;
  final String used;
}

const List<Credit> openSourceCredits = [
  Credit(
    name: 'LAME 3.100',
    licence: 'LGPL v2',
    url: 'https://lame.sourceforge.io/',
    used:
        'Encodes narration into the MP3 a Lunii storyteller plays. Shipped '
        'unmodified as a separate library, with its licence, so it can be '
        'replaced with your own build.',
  ),
];

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Moonloom is built on other people\'s work as well as ours.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final credit in openSourceCredits)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${credit.name} — ${credit.licence}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(credit.used, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    credit.url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Whether the encoder actually loaded is worth saying here rather than
        // only when a transfer fails: it is the difference between "send to
        // the Lunii" working and quietly not being an option.
        Row(
          children: [
            Icon(
              canEncodeMp3 ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: canEncodeMp3
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                canEncodeMp3
                    ? 'MP3 encoder loaded — stories can be sent straight to a '
                          'Lunii.'
                    : 'No MP3 encoder on this platform. Stories can still be '
                          'exported as a Lunii story pack for STUdio.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

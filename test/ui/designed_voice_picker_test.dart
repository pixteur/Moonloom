import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/adapters/tts/gemini_voice_designer.dart';
import 'package:moonloom/domain/models/story_character.dart';
import 'package:moonloom/ui/series/voice_design_dialog.dart';

/// Reusing a voice already designed, and the one-voice-per-world rule.
void main() {
  group('one voiced character per world', () {
    const cast = [
      StoryCharacter(id: 'p', worldId: 'w', name: 'Pip'),
      StoryCharacter(id: 'b', worldId: 'w', name: 'Barnaby', voiceId: 'v_b'),
      StoryCharacter(id: 'c', worldId: 'w', name: 'Coral'),
    ];

    // A recording holds the narrator and one other, so a second voiced
    // character could never be heard: giving Pip a voice takes Barnaby's.
    test('giving one a voice hands it over from whoever had it', () {
      final after = castWithVoice(cast, 'p', 'v_pip');
      expect(after.map((c) => c.voiceId), ['v_pip', '', '']);
    });

    test('taking a voice away leaves everyone else alone', () {
      final after = castWithVoice(cast, 'c', '');
      expect(after.map((c) => c.voiceId), ['', 'v_b', '']);
    });

    test('the cast keeps its order and its people', () {
      final after = castWithVoice(cast, 'p', 'v_pip');
      expect(after.map((c) => c.name), ['Pip', 'Barnaby', 'Coral']);
    });
  });

  group('choosing a voice already designed', () {
    const voices = [
      DesignedVoice(id: 'voice_n', name: 'Narrator', prompt: 'A warm teller'),
      DesignedVoice(id: 'voice_p', name: 'Pip', prompt: 'A bright tenor'),
    ];

    Future<DesignedVoice?> open(
      WidgetTester tester, {
      String current = '',
    }) async {
      DesignedVoice? chosen;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => chosen = await showDesignedVoicePicker(
                  context,
                  title: 'A voice for Pip',
                  voices: voices,
                  current: current,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('lists every designed voice with how it sounds', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Narrator'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      expect(find.text('A bright tenor'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsNWidgets(2));
    });

    testWidgets('tapping one chooses it', (tester) async {
      DesignedVoice? chosen;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => chosen = await showDesignedVoicePicker(
                  context,
                  title: 'A voice for Pip',
                  voices: voices,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pip'));
      await tester.pumpAndSettle();
      expect(chosen?.id, 'voice_p');
    });

    testWidgets('the voice already in use is marked', (tester) async {
      await open(tester, current: 'voice_p');
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/speech_service.dart';

class _Speaker extends StatefulWidget {
  const _Speaker();

  @override
  State<_Speaker> createState() => _SpeakerState();
}

class _SpeakerState extends State<_Speaker> with StopSpeechOnDispose {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Regression coverage for audio outliving its screen.
///
/// Leaving the listening exercise left the dialogue reading itself aloud
/// over whatever the learner opened next: TTS is a process-wide singleton
/// and nothing stopped it on the way out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('disposing a speaking screen clears the playing state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Speaker()));

    // Pretend playback is in flight. (There's no TTS engine under
    // `flutter test`, so speak() itself is a no-op — this stands in for
    // the state a real device would be in mid-sentence.)
    SpeechService.speaking.value = '你好';

    // Navigate away by replacing the tree, which disposes the screen.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(SpeechService.speaking.value, isNull);
  });

  test('stop() is safe when nothing is playing', () async {
    await SpeechService.stop();
    expect(SpeechService.speaking.value, isNull);
  });
}

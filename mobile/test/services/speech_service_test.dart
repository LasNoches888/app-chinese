import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService without a TTS engine', () {
    // There are no platform channels under `flutter test`, which is the same
    // shape of failure as a device with no Mandarin voice installed. Every
    // call has to degrade quietly instead of throwing, because speak buttons
    // are wired up all over the exercise and chat screens.
    test('reports itself unavailable rather than throwing', () async {
      expect(await SpeechService.ensureInitialized(), isFalse);
      expect(SpeechService.isAvailable, isFalse);
    });

    test('speaking is a no-op and leaves nothing marked as playing', () async {
      await SpeechService.speak('你好');
      expect(SpeechService.speaking.value, isNull);
    });

    test('stopping when nothing plays is harmless', () async {
      await SpeechService.stop();
      expect(SpeechService.speaking.value, isNull);
    });

    test('empty text never reaches the engine', () async {
      await SpeechService.speak('   ');
      expect(SpeechService.speaking.value, isNull);
    });
  });

  group('SpeechSpeed', () {
    test('slow is below the engine\'s normal pace', () {
      expect(SpeechSpeed.slow.rate, lessThan(SpeechSpeed.normal.rate));
    });

    test('normal matches the platform\'s definition of normal speed', () {
      expect(SpeechSpeed.normal.rate, 0.5);
    });
  });
}

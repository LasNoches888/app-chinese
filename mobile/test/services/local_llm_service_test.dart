import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/local_llm_service.dart';

/// Regression coverage for the readiness signal. It originally reported
/// `_chat != null`, but the chat session is only built on the first message
/// — so a freshly downloaded model read as "not ready", which disabled the
/// input box, which meant the session could never be created. The local
/// tutor was unusable no matter how the download went.
void main() {
  group('LocalLlmService.isModelReady', () {
    test('is false before anything has been loaded', () {
      expect(LocalLlmService.isModelReady, isFalse);
    });

    test('clearing the chat session does not make the model unavailable', () {
      // resetSession() runs whenever chat history is cleared. It must only
      // drop conversation memory — the weights stay loaded, so readiness
      // must not depend on the session existing.
      final before = LocalLlmService.isModelReady;
      LocalLlmService.resetSession();
      expect(LocalLlmService.isModelReady, before);
    });

    test('sending without a loaded model fails loudly, not silently', () async {
      await expectLater(
        LocalLlmService.sendMessage('你好', systemPrompt: 'test'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LocalLlmService.extractReplyJson', () {
    test('parses a bare JSON object', () {
      final parsed = LocalLlmService.extractReplyJson(
        '{"reply_zh": "你好", "reply_pinyin": "nǐ hǎo"}',
      );
      expect(parsed?['reply_zh'], '你好');
    });

    test('parses JSON inside a fenced code block', () {
      final parsed = LocalLlmService.extractReplyJson(
        'Sure!\n```json\n{"reply_zh": "谢谢"}\n```\nHope that helps.',
      );
      expect(parsed?['reply_zh'], '谢谢');
    });

    test('parses JSON embedded in surrounding prose', () {
      final parsed = LocalLlmService.extractReplyJson(
        'Here you go: {"reply_zh": "再见"} — bye!',
      );
      expect(parsed?['reply_zh'], '再见');
    });

    test('returns null for plain prose so the caller can show raw text', () {
      expect(LocalLlmService.extractReplyJson('just a sentence'), isNull);
    });
  });
}

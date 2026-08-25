import 'package:flutter/services.dart';

/// Best-effort trigger for Android's on-device speech-model download
/// (`SpeechRecognizer.triggerModelDownload`, API 33+) so there's something
/// for [PronunciationService]'s on-device recognition to run against.
///
/// A no-op everywhere the native side doesn't answer this channel — iOS,
/// pre-13 Android, and the test harness — since the app already works via
/// the regular recognizer without it.
class OfflineSpeechModelService {
  static const _channel = MethodChannel('app_chinese/speech_model');
  static bool _triggered = false;

  static Future<void> ensureDownloaded({String localeId = 'zh-CN'}) async {
    if (_triggered) return;
    _triggered = true;
    try {
      await _channel.invokeMethod('ensureOfflineModel', {
        'localeId': localeId,
      });
    } catch (_) {
      // No native implementation to answer this, or it failed — nothing to
      // recover, recognition still works without the offline model.
    }
  }
}

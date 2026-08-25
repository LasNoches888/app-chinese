package com.example.app_chinese

import android.content.Intent
import android.os.Build
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val SPEECH_MODEL_CHANNEL = "app_chinese/speech_model"

/**
 * Lets the Dart-side PronunciationService ask Android to fetch the
 * on-device speech model for a locale ahead of time, so that by the time
 * it requests on-device recognition there's actually a model installed to
 * serve it. Only possible from API 33 (Android 13) — older OSes, and any
 * platform other than Android, just never get this channel implemented,
 * which the Dart side already treats as a harmless no-op.
 */
class MainActivity : FlutterActivity() {
    // Held onto for the Activity's lifetime rather than destroyed right
    // after triggerModelDownload() — that request is asynchronous and
    // there's no documented guarantee the download survives destroying
    // the SpeechRecognizer instance that issued it.
    private var offlineModelRecognizer: SpeechRecognizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_MODEL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "ensureOfflineModel") {
                    val localeId = call.argument<String>("localeId") ?: "zh-CN"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ensureOfflineModel(localeId)
                    }
                    // Fire-and-forget either way — pre-13 devices just keep
                    // using the regular recognizer, same as before this
                    // channel existed.
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun ensureOfflineModel(localeId: String) {
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) return

        offlineModelRecognizer?.destroy()
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        offlineModelRecognizer = recognizer
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
        }
        recognizer.checkRecognitionSupport(
            intent,
            mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    val alreadyHandled =
                        support.installedOnDeviceLanguages.contains(localeId) ||
                            support.pendingOnDeviceLanguages.contains(localeId)
                    val downloadable = support.supportedOnDeviceLanguages.contains(localeId)
                    if (!alreadyHandled && downloadable) {
                        // May itself surface a system dialog (e.g. to
                        // confirm using mobile data) — that's Android's
                        // call, not something this app decides.
                        recognizer.triggerModelDownload(intent)
                    } else {
                        recognizer.destroy()
                        offlineModelRecognizer = null
                    }
                }

                override fun onError(error: Int) {
                    recognizer.destroy()
                    offlineModelRecognizer = null
                }
            },
        )
    }

    override fun onDestroy() {
        offlineModelRecognizer?.destroy()
        offlineModelRecognizer = null
        super.onDestroy()
    }
}

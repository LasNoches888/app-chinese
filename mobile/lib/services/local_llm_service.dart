import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';

/// Where the local tutor currently stands, from the UI's point of view.
enum LocalModelStatus {
  /// Nothing checked yet — the app hasn't looked for cached weights.
  unknown,

  /// No weights on disk; the learner has to download them once.
  absent,

  /// Cached weights are being read into memory (no network involved).
  loading,

  /// Weights are being fetched from HuggingFace.
  downloading,

  /// Loaded and able to answer.
  ready,
}

/// Wraps llamadart (llama.cpp) for a fully offline, on-device chat tutor —
/// running the user's own fine-tuned Qwen 1.5B (distilled from the server's
/// Qwen model, quantized to GGUF), not a stock model. The weights are
/// hosted on the user's own HuggingFace repo and downloaded once; after
/// that, every message is generated locally, no network involved.
///
/// Unlike the stateless server /chat endpoint (which rebuilds its system
/// prompt fresh every call so it never has to store anything), a local
/// session lives entirely on-device — so it keeps one real multi-turn
/// [ChatSession] alive across the whole app session instead of recreating
/// it per message, giving the local tutor actual conversation memory the
/// server path doesn't have.
class LocalLlmService {
  // TODO: replace with the real HF repo once the fine-tuned GGUF is
  // uploaded (hf upload <repo> tutor-v2-qwen1.5b-Q4_K_M.gguf).
  static const modelSource =
      'hf://REPLACE_ME/uchi-tutor-qwen1.5b/tutor-v2-qwen1.5b-Q4_K_M.gguf';

  static const _modelParams = ModelParams(contextSize: 4096, gpuLayers: 0);

  static LlamaEngine? _engine;
  static ChatSession? _chat;

  /// Lets screens rebuild the moment the model finishes loading instead of
  /// polling a getter that only changes as a side effect of other calls.
  static final ValueNotifier<LocalModelStatus> status =
      ValueNotifier<LocalModelStatus>(LocalModelStatus.unknown);

  /// Whether the tutor can answer right now.
  ///
  /// This tracks the *engine* holding loaded weights, not the chat session:
  /// the session is created lazily on the first message and thrown away
  /// whenever history is cleared, so keying readiness off it made the model
  /// look unavailable both immediately after downloading and after every
  /// history reset — with the input box disabled, there was no way to
  /// create the session that would have marked it ready.
  static bool get isModelReady => _engine?.isReady ?? false;

  static LlamaEngine get _sharedEngine =>
      _engine ??= LlamaEngine(LlamaBackend());

  /// Loads previously-downloaded weights from llamadart's on-disk cache,
  /// without touching the network. Returns false when nothing is cached
  /// yet, which is the signal to show the download panel.
  ///
  /// Needed because the loaded model only lives in memory: on a cold start
  /// the weights are still on disk but nothing has read them back, and
  /// without this the app would ask for the ~1GB download all over again.
  static Future<bool> loadFromCacheIfPresent() async {
    if (isModelReady) return true;
    status.value = LocalModelStatus.loading;
    try {
      await _sharedEngine.loadModelSource(
        ModelSource.parse(modelSource),
        modelParams: _modelParams,
        options: ModelLoadOptions(cachePolicy: ModelCachePolicy.cacheOnly),
      );
      status.value = LocalModelStatus.ready;
      return true;
    } catch (_) {
      // cacheOnly throws when there's no cached copy — that's the normal
      // "not downloaded yet" path, not an error worth surfacing.
      status.value = LocalModelStatus.absent;
      return false;
    }
  }

  static Future<void> downloadModel({
    required void Function(int percent) onProgress,
    String? huggingFaceToken,
  }) async {
    status.value = LocalModelStatus.downloading;
    try {
      await _sharedEngine.loadModelSource(
        ModelSource.parse(modelSource),
        modelParams: _modelParams,
        options: ModelLoadOptions(
          bearerToken: (huggingFaceToken?.isEmpty ?? true)
              ? null
              : huggingFaceToken,
        ),
        onProgress: (progress) {
          final fraction = progress.fraction;
          if (fraction != null) onProgress((fraction * 100).round());
        },
      );
      status.value = LocalModelStatus.ready;
    } catch (_) {
      status.value = isModelReady
          ? LocalModelStatus.ready
          : LocalModelStatus.absent;
      rethrow;
    }
  }

  /// Drops the current chat session (and its conversation memory) so the
  /// next message starts a fresh one with an up-to-date system prompt —
  /// call this whenever the learner's known/weak word set has moved on
  /// enough to matter, or when chat history is cleared. The weights stay
  /// loaded, so the tutor remains usable.
  static void resetSession() {
    _chat = null;
  }

  static ChatSession _getOrCreateChat(String systemPrompt) {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError('Model not loaded — download it in Settings first.');
    }
    return _chat ??= ChatSession(engine, systemPrompt: systemPrompt);
  }

  /// Sends one user turn and returns the model's raw text reply (still
  /// needs [extractReplyJson] applied — a 1.5B model is much less reliable
  /// at strict JSON formatting than the 7B server model).
  static Future<String> sendMessage(
    String userText, {
    required String systemPrompt,
  }) async {
    final session = _getOrCreateChat(systemPrompt);
    final buffer = StringBuffer();
    await for (final chunk in session.create([LlamaTextContent(userText)])) {
      final text = chunk.choices.first.delta.content;
      if (text != null) buffer.write(text);
    }
    return buffer.toString();
  }

  /// Same lenient extraction the backend does for the server model
  /// (app/llm_client.py's _extract_json) — a raw JSON object, one fenced
  /// in a ```json block, or the first {...} found anywhere in the text.
  /// Returns null if nothing parses, so the caller can fall back to
  /// showing the raw text rather than erroring out.
  static Map<String, dynamic>? extractReplyJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // fall through to the more lenient extraction below
    }

    final fenced = RegExp(
      r'```(?:json)?\s*(\{.*?\})\s*```',
      dotAll: true,
    ).firstMatch(text);
    if (fenced != null) {
      try {
        final decoded = jsonDecode(fenced.group(1)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    final brace = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    if (brace != null) {
      try {
        final decoded = jsonDecode(brace.group(0)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';

/// Where a given local model variant currently stands, from the UI's point
/// of view.
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

/// The two on-device personas. Both are Qwen 1.5B GGUF checkpoints (small
/// enough to run on a phone CPU) but fine-tuned differently: Friend for
/// loose, casual chat, Tutor for structured HSK-paced practice. The big
/// server-side model ("Professor") is a separate, much larger checkpoint
/// that only ever runs on the backend — never a candidate for on-device.
enum LocalModelVariant { friend, tutor }

/// Wraps llamadart (llama.cpp) for fully offline, on-device chat — running
/// the user's own fine-tuned checkpoints, not stock models. Weights are
/// hosted on the user's own HuggingFace repo and downloaded once per
/// variant; after that, every message for that persona is generated
/// locally, no network involved.
///
/// Only one variant is ever loaded into memory at a time (two 1.5B models
/// loaded simultaneously would be a needless ~2GB+ RAM footprint on a
/// phone) — switching personas unloads whichever one is active and loads
/// the other from its own on-disk cache, which is fast since no network is
/// involved once both have been downloaded at least once.
///
/// Unlike the stateless server /chat endpoint (which rebuilds its system
/// prompt fresh every call so it never has to store anything), a local
/// session lives entirely on-device — so it keeps one real multi-turn
/// [ChatSession] alive across the whole app session instead of recreating
/// it per message, giving the local personas actual conversation memory
/// the server path doesn't have.
class LocalLlmService {
  static const Map<LocalModelVariant, String> _modelSources = {
    LocalModelVariant.friend:
        'hf://LasNoches888/ChineseTeacher/friend-v2-qwen1.5b-Q4_K_M.gguf',
    LocalModelVariant.tutor:
        'hf://LasNoches888/ChineseTeacher/tutor-v3-qwen1.5b-Q4_K_M.gguf',
  };

  static const _modelParams = ModelParams(contextSize: 4096, gpuLayers: 0);

  static LlamaEngine? _engine;
  static ChatSession? _chat;

  /// Which variant's weights are currently loaded into [_engine], if any.
  static LocalModelVariant? _loadedVariant;

  /// Lets screens rebuild the moment a variant's status changes instead of
  /// polling a getter that only changes as a side effect of other calls.
  /// Each variant tracks its own status independently — downloading Friend
  /// doesn't touch Tutor's state, since their weights live in separate
  /// on-disk cache entries.
  static final Map<LocalModelVariant, ValueNotifier<LocalModelStatus>> status =
      {
        LocalModelVariant.friend: ValueNotifier(LocalModelStatus.unknown),
        LocalModelVariant.tutor: ValueNotifier(LocalModelStatus.unknown),
      };

  /// Download percent (0-100) for whichever variant is currently
  /// downloading. Lives here rather than in a screen's State so the persona
  /// picker can show live progress no matter which screen kicked the
  /// download off.
  static final Map<LocalModelVariant, ValueNotifier<int>> downloadProgress = {
    LocalModelVariant.friend: ValueNotifier(0),
    LocalModelVariant.tutor: ValueNotifier(0),
  };

  /// Whether [variant] specifically can answer right now — false both when
  /// nothing is loaded and when the *other* variant is the one currently
  /// loaded into the engine.
  static bool isModelReady(LocalModelVariant variant) =>
      _loadedVariant == variant && (_engine?.isReady ?? false);

  static LlamaEngine get _sharedEngine =>
      _engine ??= LlamaEngine(LlamaBackend());

  /// Unloads whatever's currently loaded so a different variant can take
  /// its place. No-op if the engine is already empty or already holds
  /// [target].
  static Future<void> _ensureUnloadedIfDifferent(
    LocalModelVariant target,
  ) async {
    final engine = _engine;
    if (engine == null || !engine.isReady || _loadedVariant == target) return;
    await engine.unloadModel();
    _loadedVariant = null;
    _chat = null;
  }

  /// Loads previously-downloaded weights for [variant] from llamadart's
  /// on-disk cache, without touching the network. Returns false when
  /// nothing is cached yet, which is the signal to show the download panel.
  ///
  /// Needed because the loaded model only lives in memory: on a cold start
  /// the weights are still on disk but nothing has read them back, and
  /// without this the app would ask for the ~1GB download all over again.
  static Future<bool> loadFromCacheIfPresent(LocalModelVariant variant) async {
    if (isModelReady(variant)) return true;
    status[variant]!.value = LocalModelStatus.loading;
    try {
      await _ensureUnloadedIfDifferent(variant);
      await _sharedEngine.loadModelSource(
        ModelSource.parse(_modelSources[variant]!),
        modelParams: _modelParams,
        options: ModelLoadOptions(cachePolicy: ModelCachePolicy.cacheOnly),
      );
      _loadedVariant = variant;
      status[variant]!.value = LocalModelStatus.ready;
      return true;
    } catch (_) {
      // cacheOnly throws when there's no cached copy — that's the normal
      // "not downloaded yet" path, not an error worth surfacing.
      status[variant]!.value = LocalModelStatus.absent;
      return false;
    }
  }

  static Future<void> downloadModel(LocalModelVariant variant) async {
    status[variant]!.value = LocalModelStatus.downloading;
    downloadProgress[variant]!.value = 0;
    try {
      await _ensureUnloadedIfDifferent(variant);
      await _sharedEngine.loadModelSource(
        ModelSource.parse(_modelSources[variant]!),
        modelParams: _modelParams,
        // A resumed download depends on the server returning the same
        // validator (ETag/Last-Modified) it gave the first attempt — if an
        // earlier try was interrupted (app killed, connection dropped) and
        // that validator no longer matches, resuming can get permanently
        // stuck instead of falling back to a clean download. Always
        // starting over from zero is a little slower on a real retry but
        // guarantees "tap the button again" actually works.
        options: ModelLoadOptions(resume: false),
        onProgress: (progress) {
          final fraction = progress.fraction;
          if (fraction != null) {
            downloadProgress[variant]!.value = (fraction * 100).round();
          }
        },
      );
      _loadedVariant = variant;
      status[variant]!.value = LocalModelStatus.ready;
    } catch (_) {
      status[variant]!.value = isModelReady(variant)
          ? LocalModelStatus.ready
          : LocalModelStatus.absent;
      rethrow;
    }
  }

  /// Checks the on-disk cache and, if nothing's there, downloads — the
  /// single entry point screens call after the learner picks a persona, so
  /// "select the persona" is the only action needed. Swallows download
  /// failures (status already reflects `absent` for the retry UI to key
  /// off); callers that want to react to the error should watch [status]
  /// rather than await this throwing.
  static Future<void> ensureReady(LocalModelVariant variant) async {
    final cached = await loadFromCacheIfPresent(variant);
    if (cached) return;
    try {
      await downloadModel(variant);
    } catch (_) {
      // status[variant] is already `absent` — the picker's retry row
      // covers this without needing the exception itself.
    }
  }

  /// Drops the current chat session (and its conversation memory) so the
  /// next message starts a fresh one with an up-to-date system prompt —
  /// call this whenever the learner's known/weak word set has moved on
  /// enough to matter, or when chat history is cleared. The weights stay
  /// loaded, so the active persona remains usable.
  static void resetSession() {
    _chat = null;
  }

  static ChatSession _getOrCreateChat(
    LocalModelVariant variant,
    String systemPrompt,
  ) {
    final engine = _engine;
    if (engine == null || !engine.isReady || _loadedVariant != variant) {
      throw StateError('Model not loaded — download it in Settings first.');
    }
    return _chat ??= ChatSession(engine, systemPrompt: systemPrompt);
  }

  /// Sends one user turn to [variant] and returns the model's raw text
  /// reply (still needs [extractReplyJson] applied — a 1.5B model is much
  /// less reliable at strict JSON formatting than the 7B server model).
  static Future<String> sendMessage(
    LocalModelVariant variant,
    String userText, {
    required String systemPrompt,
  }) async {
    final session = _getOrCreateChat(variant, systemPrompt);
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

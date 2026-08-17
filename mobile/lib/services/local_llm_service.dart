import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

/// Wraps flutter_gemma for a fully offline, on-device chat tutor. The model
/// file itself must be downloaded once (needs a HuggingFace token — Gemma
/// weights are gated); after that, every message is generated locally, no
/// network involved.
///
/// Unlike the stateless server /chat endpoint (which rebuilds its system
/// prompt fresh every call so it never has to store anything), a local
/// session lives entirely on-device — so it keeps one real multi-turn
/// [InferenceChat] alive across the whole app session instead of
/// recreating it per message, giving the local tutor actual conversation
/// memory the server path doesn't have.
class LocalLlmService {
  // int4-quantized, MediaPipe .task format — the mobile-native path (as
  // opposed to .litertlm, which this package suite treats as the
  // desktop-oriented format). ~500MB on disk.
  static const modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';

  static bool _engineRegistered = false;
  static InferenceChat? _chat;

  static void ensureEngineRegistered() {
    if (_engineRegistered) return;
    _engineRegistered = true;
    FlutterGemma.initialize(inferenceEngines: [const MediaPipeEngine()]);
  }

  /// Safe to call before the model has ever been downloaded — makes sure the
  /// inference engine is registered first (flutter_gemma throws if you query
  /// model state before that) and treats any unexpected native error as
  /// "not ready" instead of letting it crash whatever screen checks this.
  static bool get isModelReady {
    try {
      ensureEngineRegistered();
      return FlutterGemma.hasActiveModel();
    } catch (_) {
      return false;
    }
  }

  static Future<void> downloadModel({
    required String huggingFaceToken,
    required void Function(int percent) onProgress,
  }) async {
    ensureEngineRegistered();
    await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(modelUrl, token: huggingFaceToken)
        .withProgress(onProgress)
        .install();
  }

  /// Drops the current chat session (and its conversation memory) so the
  /// next message starts a fresh one with an up-to-date system prompt —
  /// call this whenever the learner's known/weak word set has moved on
  /// enough to matter, or when chat history is cleared.
  static void resetSession() {
    _chat?.close();
    _chat = null;
  }

  static Future<InferenceChat> _getOrCreateChat(String systemPrompt) async {
    final existing = _chat;
    if (existing != null) return existing;
    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    final chat = await model.createChat(systemInstruction: systemPrompt);
    _chat = chat;
    return chat;
  }

  /// Sends one user turn and returns the model's raw text reply (still
  /// needs [extractReplyJson] applied — a 1B model is much less reliable
  /// at strict JSON formatting than the 7B server model).
  static Future<String> sendMessage(String userText,
      {required String systemPrompt}) async {
    final chat = await _getOrCreateChat(systemPrompt);
    await chat.addQueryChunk(Message.text(text: userText, isUser: true));
    final response = await chat.generateChatResponse();
    if (response is TextResponse) return response.token;
    return '';
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

    final fenced = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true)
        .firstMatch(text);
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

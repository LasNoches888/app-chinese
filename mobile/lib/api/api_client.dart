import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// Talks to exactly one backend endpoint: /chat. Every other feature
/// (vocab, SRS, stats, decks) is local-only — see AppRepositories — so
/// the app works fully offline except for this one call.
class ChatApiClient {
  final String baseUrl;

  ChatApiClient({required this.baseUrl});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// [knownWords]/[weakWords] are the caller's current local vocabulary
  /// snapshot, sent with each request so the tutor can personalize its
  /// reply — the backend itself stores no history or per-user state.
  Future<ChatMessage> sendChatMessage(
    String message, {
    int hskLevel = 1,
    List<String> knownWords = const [],
    List<String> weakWords = const [],
  }) async {
    final res = await http
        .post(
          _uri('/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': 'local',
            'message': message,
            'hsk_level': hskLevel,
            'known_words': knownWords,
            'weak_words': weakWords,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
    return ChatMessage.fromReplyJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}

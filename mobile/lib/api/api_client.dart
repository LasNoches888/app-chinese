import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/deck.dart';
import '../models/user_stats.dart';
import '../models/vocab_card.dart';

class ApiClient {
  final String baseUrl;
  final String userId;

  ApiClient({required this.baseUrl, required this.userId});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<VocabCard>> fetchDueCards() async {
    final res = await http.get(_uri('/users/$userId/vocab/due'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => VocabCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VocabCard>> fetchAllCards() async {
    final res = await http.get(_uri('/users/$userId/vocab'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => VocabCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VocabCard> addCard({
    required String word,
    required String pinyin,
    required String translation,
  }) async {
    final res = await http.post(
      _uri('/users/$userId/vocab'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'word': word, 'pinyin': pinyin, 'translation': translation}),
    );
    _checkOk(res);
    return VocabCard.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<VocabCard> reviewCard({required String cardId, required int quality}) async {
    final res = await http.post(
      _uri('/users/$userId/vocab/review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'card_id': cardId, 'quality': quality}),
    );
    _checkOk(res);
    return VocabCard.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ChatMessage> sendChatMessage(String message, {int hskLevel = 1}) async {
    final res = await http.post(
      _uri('/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'message': message, 'hsk_level': hskLevel}),
    );
    _checkOk(res);
    return ChatMessage.fromReplyJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserStats> fetchStats() async {
    final res = await http.get(_uri('/users/$userId/stats'));
    _checkOk(res);
    return UserStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<DeckSummary>> fetchDecks() async {
    final res = await http.get(_uri('/decks'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => DeckSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> importDeck(String deckId) async {
    final res = await http.post(
      _uri('/users/$userId/vocab/import-deck'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deck_id': deckId}),
    );
    _checkOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.length;
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}

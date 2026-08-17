import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

/// Persists chat history locally (chat_messages table) so it survives app
/// restarts even though the messages themselves come from a network call.
class ChatRepository {
  final Database db;

  ChatRepository(this.db);

  Future<List<ChatMessage>> getHistory() async {
    final rows = await db.query('chat_messages', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<ChatMessage> addUserMessage(String text) async {
    final now = DateTime.now();
    final id = await db.insert('chat_messages', {
      'role': 'user',
      'content': text,
      'created_at': now.millisecondsSinceEpoch,
    });
    return ChatMessage(id: id, fromUser: true, text: text, createdAt: now);
  }

  Future<ChatMessage> addAssistantMessage(ChatMessage message) async {
    final now = DateTime.now();
    final payload = jsonEncode({
      'text': message.text,
      'pinyin': message.pinyin,
      'grammar_recast': message.grammarRecast,
      'new_words': message.newWords.map((w) => w.toJson()).toList(),
    });
    final id = await db.insert('chat_messages', {
      'role': 'assistant',
      'content': payload,
      'created_at': now.millisecondsSinceEpoch,
    });
    return ChatMessage(
      id: id,
      fromUser: false,
      text: message.text,
      pinyin: message.pinyin,
      grammarRecast: message.grammarRecast,
      newWords: message.newWords,
      createdAt: now,
    );
  }

  Future<void> clearHistory() async {
    await db.delete('chat_messages');
  }

  ChatMessage _fromRow(Map<String, Object?> row) {
    final role = row['role'] as String;
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
    if (role == 'user') {
      return ChatMessage(
        id: row['id'] as int,
        fromUser: true,
        text: row['content'] as String,
        createdAt: createdAt,
      );
    }
    final decoded =
        jsonDecode(row['content'] as String) as Map<String, dynamic>;
    return ChatMessage(
      id: row['id'] as int,
      fromUser: false,
      text: decoded['text'] as String,
      pinyin: decoded['pinyin'] as String?,
      grammarRecast: decoded['grammar_recast'] as String?,
      newWords: (decoded['new_words'] as List<dynamic>? ?? [])
          .map((e) => NewWord.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: createdAt,
    );
  }
}

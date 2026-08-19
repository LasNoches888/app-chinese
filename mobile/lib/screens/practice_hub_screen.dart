import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import 'dictionary_screen.dart';
import 'listening_screen.dart';
import 'memory_match_screen.dart';
import 'placement_test_screen.dart';
import 'reading_list_screen.dart';
import 'scenario_list_screen.dart';
import 'settings_screen.dart';
import 'tone_trainer_screen.dart';

/// Entry point for the practice modes that sit outside the core SRS lesson
/// loop: tone drilling, listening, reading, roleplay, and the one-off
/// placement pass. Grouped behind one tab rather than each getting its own
/// nav destination, since none of them are used daily the way lessons/
/// review/chat are.
class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('practiceHub')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PracticeCard(
              emoji: '🧠',
              title: settings.t('memoryMatchTitle'),
              subtitle: settings.t('memoryMatchCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MemoryMatchScreen(),
                ),
              ),
            ),
            _PracticeCard(
              emoji: '🎵',
              title: settings.t('toneTrainerTitle'),
              subtitle: settings.t('toneTrainerCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ToneTrainerScreen(),
                ),
              ),
            ),
            _PracticeCard(
              emoji: '🎧',
              title: settings.t('listeningTitle'),
              subtitle: settings.t('listeningCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ListeningScreen(),
                ),
              ),
            ),
            _PracticeCard(
              emoji: '📖',
              title: settings.t('readingTitle'),
              subtitle: settings.t('readingCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReadingListScreen(),
                ),
              ),
            ),
            _PracticeCard(
              emoji: '🎭',
              title: settings.t('scenariosTitle'),
              subtitle: settings.t('scenariosCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScenarioListScreen(),
                ),
              ),
            ),
            const Divider(height: 32),
            _PracticeCard(
              emoji: '🔍',
              title: settings.t('dictionaryTitle'),
              subtitle: settings.t('dictionaryCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DictionaryScreen(),
                ),
              ),
            ),
            _PracticeCard(
              emoji: '📝',
              title: settings.t('placementTitle'),
              subtitle: settings.t('placementCardDesc'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PlacementTestScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 30)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

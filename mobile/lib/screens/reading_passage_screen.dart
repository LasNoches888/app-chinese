import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../services/speech_service.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/reading_passage.dart';

class ReadingPassageScreen extends StatefulWidget {
  final ReadingPassage passage;

  const ReadingPassageScreen({super.key, required this.passage});

  @override
  State<ReadingPassageScreen> createState() => _ReadingPassageScreenState();
}

class _ReadingPassageScreenState extends State<ReadingPassageScreen>
    with StopSpeechOnDispose {
  bool _showTranslation = false;
  int? _selectedOption;
  bool _xpAwarded = false;

  Future<void> _pickOption(int index) async {
    if (_selectedOption != null) return;
    setState(() => _selectedOption = index);
    if (index == widget.passage.correctIndex && !_xpAwarded) {
      _xpAwarded = true;
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(8);
    }
  }

  Color? _optionColor(int index) {
    if (_selectedOption == null) return null;
    if (index == widget.passage.correctIndex) {
      return Colors.green.withValues(alpha: 0.25);
    }
    if (index == _selectedOption) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final passage = widget.passage;
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('readingTitle'))),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              passage.text,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(height: 1.6),
                            ),
                          ),
                          SpeakButton(text: passage.text, size: 24),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_showTranslation)
                        Text(
                          passage.translationRu,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        )
                      else
                        TextButton(
                          onPressed: () =>
                              setState(() => _showTranslation = true),
                          child: Text(settings.t('readingShowTranslation')),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                passage.question,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < passage.options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _optionColor(i),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _pickOption(i),
                      child: Text(passage.options[i]),
                    ),
                  ),
                ),
              if (_selectedOption != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(settings.t('continueLabel')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

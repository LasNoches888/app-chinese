import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<AppSettings>().baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('settings'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.t('backendUrl')),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                context.read<AppSettings>().setBaseUrl(_controller.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(settings.t('saved'))),
                );
              },
              child: Text(settings.t('save')),
            ),
            const SizedBox(height: 32),
            Text(settings.t('language')),
            const SizedBox(height: 8),
            SegmentedButton<AppLocale>(
              segments: const [
                ButtonSegment(value: AppLocale.ru, label: Text('Русский')),
                ButtonSegment(value: AppLocale.en, label: Text('English')),
              ],
              selected: {settings.locale},
              onSelectionChanged: (s) => context.read<AppSettings>().setLocale(s.first),
            ),
            const SizedBox(height: 32),
            Text(settings.t('cardFrontSideLabel')),
            const SizedBox(height: 8),
            SegmentedButton<CardFrontSide>(
              segments: [
                ButtonSegment(value: CardFrontSide.hanzi, label: Text(settings.t('cardFrontHanzi'))),
                ButtonSegment(
                  value: CardFrontSide.translation,
                  label: Text(settings.t('cardFrontTranslation')),
                ),
              ],
              selected: {settings.cardFrontSide},
              onSelectionChanged: (s) => context.read<AppSettings>().setCardFrontSide(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

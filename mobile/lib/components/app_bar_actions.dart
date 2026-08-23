import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';

/// The chat and settings buttons every main screen carries.
///
/// One widget rather than a pair copy-pasted into each app bar: that
/// copy-paste is exactly how the chat button ended up reachable from one
/// screen only, while the gear was on five.
class AppBarActions extends StatelessWidget {
  const AppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: settings.t('chat'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ChatScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: settings.t('settings'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

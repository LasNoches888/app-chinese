import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../models/user_stats.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  UserStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await context.read<AppSettings>().client.fetchStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('progress')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('${settings.t('error')}: $_error', textAlign: TextAlign.center));
    }
    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _StatCard(
            icon: Icons.local_fire_department,
            iconColor: Colors.deepOrange,
            label: settings.t('streakDays'),
            value: '${stats.streakDays}',
          ),
          _StatCard(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            label: settings.t('learnedWords'),
            value: '${stats.learnedWords}',
          ),
          _StatCard(
            icon: Icons.menu_book,
            iconColor: Colors.blue,
            label: settings.t('totalWords'),
            value: '${stats.totalWords}',
          ),
          _StatCard(
            icon: Icons.error_outline,
            iconColor: Colors.orange,
            label: settings.t('weakWords'),
            value: '${stats.weakWords}',
          ),
          _StatCard(
            icon: Icons.today,
            iconColor: Colors.purple,
            label: settings.t('reviewsToday'),
            value: '${stats.reviewsToday}',
          ),
          _StatCard(
            icon: Icons.percent,
            iconColor: Colors.teal,
            label: settings.t('accuracy'),
            value: '${stats.accuracyPercent.toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

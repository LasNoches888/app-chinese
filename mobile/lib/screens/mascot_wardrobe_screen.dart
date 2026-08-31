import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/mascot_3d_stage.dart';
import '../models/user_stats.dart';
import '../services/mascot_service.dart';
import '../services/xp_service.dart';

/// Pick a companion (panda or pug) and dress it in whatever outfit the
/// current level has unlocked. Reachable by tapping the mascot on the home
/// screen.
class MascotWardrobeScreen extends StatefulWidget {
  const MascotWardrobeScreen({super.key});

  @override
  State<MascotWardrobeScreen> createState() => _MascotWardrobeScreenState();
}

class _MascotWardrobeScreenState extends State<MascotWardrobeScreen> {
  UserStats? _stats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final stats = await context.read<AppRepositories>().stats.getStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _pickCharacter(MascotCharacter character) async {
    final repo = context.read<AppRepositories>().stats;
    final stats = await repo.setMascotCharacter(character.dbValue);
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _equip(MascotOutfit outfit) async {
    final repo = context.read<AppRepositories>().stats;
    final stats = await repo.setEquippedOutfit(outfit.index);
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('mascotWardrobeTitle'))),
      body: AppBackground(
        child: stats == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, settings, stats),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppSettings settings,
    UserStats stats,
  ) {
    final character = MascotCharacter.fromDb(stats.mascotCharacter);
    final level = XpService.levelForXp(stats.totalXp);
    final outfits = MascotService.outfitsFor(character);
    // TODO: temporary, same as the `unlocked: true` below — picking any
    // outfit here should stick regardless of the real requiredLevel while
    // every outfit is being tried out. effectiveOutfit still enforces that
    // level gate, so it would silently revert an equip the moment it fell
    // outside the actual unlocked tier. Go back to
    // `MascotService.effectiveOutfit(character, stats.equippedOutfit,
    // level).index` once that's done.
    final equippedIndex = stats.equippedOutfit >= 0
        ? stats.equippedOutfit
        : MascotService.effectiveOutfit(
            character,
            stats.equippedOutfit,
            level,
          ).index;

    // Keyed on the character alone — that's the only thing that requires
    // a genuinely new 3D model (a new ViewerWidget.assetPath, which can't
    // change in place). Keying on the outfit index as well used to tear
    // down and recreate the whole Filament engine on every tap in the
    // grid below, even between outfits that render identically (most
    // outfits are still 2D-only); racing that teardown/recreate is very
    // likely why switching outfits could show a blank colored square or
    // crash — see the "only one viewer can be active at a time" warning
    // in Thermion's own docs. Mascot3DStage now swaps the equipped prop
    // in place (via didUpdateWidget) instead of needing a new widget.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Mascot3DStage(
          key: ValueKey(character.name),
          character: character,
          outfitIndex: equippedIndex,
        ),
        const SizedBox(height: 20),
        Text(
          settings.t('mascotPickCompanion'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CharacterCard(
                character: MascotCharacter.panda,
                label: settings.t('mascotPanda'),
                selected: character == MascotCharacter.panda,
                onTap: () => _pickCharacter(MascotCharacter.panda),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CharacterCard(
                character: MascotCharacter.pug,
                label: settings.t('mascotPug'),
                selected: character == MascotCharacter.pug,
                onTap: () => _pickCharacter(MascotCharacter.pug),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          settings.t('mascotOutfitsTitle'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            for (final outfit in outfits)
              _OutfitCard(
                outfit: outfit,
                settings: settings,
                // TODO: temporary — every outfit shows unlocked so the new
                // 3D stage can be tried out with all of them. Revert to
                // `outfit.requiredLevel <= level` once that's done.
                unlocked: true,
                equipped: outfit.index == equippedIndex,
                onTap: () => _equip(outfit),
              ),
          ],
        ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final MascotCharacter character;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.character,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = MascotService.outfitsFor(character).first.asset;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Image.asset(asset, height: 64),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  final MascotOutfit outfit;
  final AppSettings settings;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;

  const _OutfitCard({
    required this.outfit,
    required this.settings,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: unlocked ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: equipped
              ? const LinearGradient(
                  colors: [Color(0xFFFFB03A), Color(0xFFFF7A59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: equipped
              ? null
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: equipped
              ? null
              : Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.4,
              child: Image.asset(outfit.asset, height: 72),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t(outfit.labelKey),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: equipped ? Colors.white : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (equipped)
                  const Icon(Icons.check_circle, size: 16, color: Colors.white)
                else if (!unlocked)
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
            if (!unlocked)
              Text(
                '${settings.t('mascotLockedUntil')} ${outfit.requiredLevel}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../services/app_update_service.dart';

const _accentGreen = Color(0xFF23C58F);
const _accentBlue = Color(0xFF4E7CFF);

enum _UpdateStatus {
  idle,
  checking,
  upToDate,
  checkFailed,
  available,
  downloading,
  downloadFailed,
}

/// Lets someone sideloading builds from GitHub see what's new without
/// uninstalling first — see AppUpdateService for why that used to be
/// necessary and isn't anymore.
class UpdateSection extends StatefulWidget {
  /// Test seam: PackageInfo.fromPlatform() has no fallback under
  /// `flutter test` (it needs a real platform channel) — a fake loader
  /// lets the version line be exercised without one. Null (every real
  /// call site) means the real platform lookup.
  final Future<String> Function()? versionLabel;

  const UpdateSection({super.key, this.versionLabel});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  _UpdateStatus _status = _UpdateStatus.idle;
  AppUpdate? _update;
  double _progress = 0;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final label = widget.versionLabel == null
          ? await _platformVersionLabel()
          : await widget.versionLabel!();
      if (!mounted) return;
      setState(() => _currentVersion = label);
    } catch (_) {
      // Worst case this line just doesn't show — the version number is
      // informational, not load-bearing for anything else on the screen.
    }
  }

  static Future<String> _platformVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  Future<void> _check() async {
    setState(() => _status = _UpdateStatus.checking);
    try {
      final update = await AppUpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _update = update;
        _status = update == null
            ? _UpdateStatus.upToDate
            : _UpdateStatus.available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _UpdateStatus.checkFailed);
    }
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null) return;
    setState(() {
      _status = _UpdateStatus.downloading;
      _progress = 0;
    });
    try {
      // A prior attempt may have already finished — e.g. the app got
      // backgrounded mid-download and the OS killed the process, which
      // drops this widget's state (back to square one, as far as it
      // knows) but not a download that had actually completed by then.
      // Without this, that always meant redownloading from zero.
      final path =
          await AppUpdateService.alreadyDownloaded(update) ??
          await AppUpdateService.download(
            update,
            onProgress: (fraction) {
              if (mounted) setState(() => _progress = fraction);
            },
          );
      if (!mounted) return;
      // Fires the OS's own installer and returns immediately — the
      // actual install happens in that UI from here on (and, on
      // Windows, closes this app to do it — see CloseApplications in
      // uchi.iss), so there is no further state to track here.
      await AppUpdateService.install(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _UpdateStatus.downloadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentVersion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${settings.t('currentVersion')}: $_currentVersion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        switch (_status) {
          _UpdateStatus.checking => _StatusLine(
            icon: null,
            spinner: true,
            text: settings.t('checkingForUpdate'),
          ),
          _UpdateStatus.upToDate => _StatusLine(
            icon: Icons.check_circle_outline,
            color: _accentGreen,
            text: settings.t('upToDate'),
          ),
          _UpdateStatus.checkFailed => _StatusLine(
            icon: Icons.error_outline,
            color: Colors.red,
            text: settings.t('updateCheckFailed'),
          ),
          _UpdateStatus.available => _StatusLine(
            icon: Icons.new_releases_outlined,
            color: _accentBlue,
            text: settings
                .t('updateAvailable')
                .replaceFirst('{build}', '${_update!.buildNumber}'),
          ),
          _UpdateStatus.downloading => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${settings.t('downloadingUpdate')} ${(_progress * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          _UpdateStatus.downloadFailed => _StatusLine(
            icon: Icons.error_outline,
            color: Colors.red,
            text: settings.t('updateDownloadFailed'),
          ),
          _UpdateStatus.idle => const SizedBox.shrink(),
        },
        if (_status != _UpdateStatus.downloading) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _status == _UpdateStatus.available
                ? FilledButton.icon(
                    onPressed: _downloadAndInstall,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(settings.t('downloadAndInstall')),
                  )
                : OutlinedButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh),
                    label: Text(settings.t('checkForUpdate')),
                  ),
          ),
        ],
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final bool spinner;
  final String text;

  const _StatusLine({
    this.icon,
    this.color,
    this.spinner = false,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spinner)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: color ?? theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

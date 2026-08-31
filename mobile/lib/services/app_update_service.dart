import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// One available update: enough to show it and fetch it.
class AppUpdate {
  final int buildNumber;
  final String assetName;
  final String assetUrl;
  final int? assetSizeBytes;

  const AppUpdate({
    required this.buildNumber,
    required this.assetName,
    required this.assetUrl,
    this.assetSizeBytes,
  });
}

/// Checks GitHub Releases for a newer build than the one currently
/// running, and installs it.
///
/// There is no app store here — every release is this repo's CI
/// uploading platform installers to GitHub (see
/// .github/workflows/build-apk.yml: one job per platform, both attaching
/// to the same tagged release), so "is there an update" is answerable
/// without any server of the app's own. The release tag is the CI run
/// number, which only ever goes up, so comparing versions is a plain
/// integer diff rather than a semver parse.
///
/// Each platform gets its own asset in the same release — an .apk for
/// Android, an installer exe for Windows — and this picks the one that
/// matches wherever it's actually running, by the suffix CI names that
/// asset with. A release missing the current platform's asset (e.g. the
/// Windows build failed that run) is treated as a failed check, not a
/// missing update — offering a download that doesn't exist for this
/// platform would be worse than not checking at all.
///
/// Nothing here runs unprompted: this only checks and reports when
/// asked, and only downloads or installs on an explicit tap — someone
/// sideloading builds like this is trusting exactly one source (this
/// repo's own CI), and that trust shouldn't extend to acting without
/// them asking.
class AppUpdateService {
  static const _releasesUrl =
      'https://api.github.com/repos/LasNoches888/app-chinese/releases/latest';

  static final _buildNumber = RegExp(r'\d+');

  /// How CI names each platform's release asset — see
  /// build-windows/build-android in the workflow.
  static String _assetSuffixForPlatform() {
    if (Platform.isAndroid) return '.apk';
    if (Platform.isWindows) return 'Setup.exe';
    throw UnsupportedError('Self-update is not offered on this platform');
  }

  /// Checks for an update.
  ///
  /// Returns null when the check succeeded and the running build is
  /// already current — a real answer, not a failure. Anything that stops
  /// the check from completing (no connection, GitHub down, an
  /// unparseable response, no asset for this platform) throws instead, so
  /// the caller can tell "you're current" from "couldn't find out" and
  /// say so.
  ///
  /// [client], [localBuildNumber] and [assetSuffix] are test seams —
  /// production callers never pass them, and get a real HTTP client, the
  /// actual installed build number, and the real platform's asset
  /// suffix.
  static Future<AppUpdate?> checkForUpdate({
    http.Client? client,
    int? localBuildNumber,
    String? assetSuffix,
  }) async {
    final effectiveClient = client ?? http.Client();
    final response = await effectiveClient
        .get(
          Uri.parse(_releasesUrl),
          // The GitHub API rejects requests with no User-Agent.
          headers: const {'User-Agent': 'uchi-app-update-check'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('GitHub вернул ${response.statusCode}');
    }

    final release = jsonDecode(response.body) as Map<String, dynamic>;

    final tag = release['tag_name'] as String? ?? '';
    final remoteBuild = int.tryParse(_buildNumber.firstMatch(tag)?[0] ?? '');
    if (remoteBuild == null) {
      throw const FormatException('Release tag has no build number');
    }

    final localBuild =
        localBuildNumber ??
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ??
        0;
    if (remoteBuild <= localBuild) return null;

    final suffix = assetSuffix ?? _assetSuffixForPlatform();
    final assets = release['assets'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? match;
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      if ((map['name'] as String? ?? '').endsWith(suffix)) {
        match = map;
        break;
      }
    }
    if (match == null) {
      throw FormatException('Release has no $suffix asset for this platform');
    }

    return AppUpdate(
      buildNumber: remoteBuild,
      assetName: match['name'] as String,
      assetUrl: match['browser_download_url'] as String,
      assetSizeBytes: match['size'] as int?,
    );
  }

  /// Where [update]'s installer is (or would be) saved — named after the
  /// build it holds, so a second download doesn't race a first one still
  /// being read by the installer, and a stale file from an old check is
  /// never mistaken for a fresh one.
  static Future<String> _pathFor(AppUpdate update, {Directory? saveDir}) async {
    final dir = saveDir ?? await getTemporaryDirectory();
    final dotIndex = update.assetName.lastIndexOf('.');
    final extension = dotIndex < 0 ? '' : update.assetName.substring(dotIndex);
    return '${dir.path}/uchi-update-${update.buildNumber}$extension';
  }

  /// A previous [download] of [update] already sitting in the cache, if
  /// one finished completely — checked by size against what GitHub
  /// reported for the asset, not just existence, since backgrounding the
  /// app mid-download can get the whole process killed (Android reclaims
  /// backgrounded apps aggressively, and this download isn't tied to a
  /// foreground service or any OS-level background-transfer API), which
  /// leaves a truncated file under the same name rather than no file at
  /// all. Without this check, every such interruption meant redownloading
  /// from zero even when a *later* attempt had actually completed, because
  /// the in-memory UI state (also reset by that same process kill) had no
  /// way to tell "downloaded" apart from "never tried".
  static Future<String?> alreadyDownloaded(
    AppUpdate update, {
    Directory? saveDir,
  }) async {
    final path = await _pathFor(update, saveDir: saveDir);
    final file = File(path);
    if (!await file.exists()) return null;
    final expectedSize = update.assetSizeBytes;
    if (expectedSize != null && await file.length() != expectedSize) {
      return null;
    }
    return path;
  }

  /// Downloads [update]'s installer to a private cache file, reporting
  /// progress as a 0–1 fraction when the server states a size (GitHub
  /// always does for release assets, so this is effectively always
  /// available).
  ///
  /// The saved file keeps [AppUpdate.assetName]'s extension — Windows in
  /// particular decides how to open a file by that extension, so a
  /// Setup.exe saved without one wouldn't run as an installer.
  ///
  /// [client] and [saveDir] are test seams, same as in [checkForUpdate].
  static Future<String> download(
    AppUpdate update, {
    void Function(double fraction)? onProgress,
    http.Client? client,
    Directory? saveDir,
  }) async {
    final request = http.Request('GET', Uri.parse(update.assetUrl));
    final response = await (client ?? http.Client()).send(request);
    if (response.statusCode != 200) {
      throw HttpException('Скачивание не удалось: ${response.statusCode}');
    }

    final total = response.contentLength ?? update.assetSizeBytes ?? 0;
    var received = 0;

    final file = File(await _pathFor(update, saveDir: saveDir));
    final sink = file.openWrite();
    try {
      await response.stream
          .map((chunk) {
            received += chunk.length;
            if (total > 0) onProgress?.call(received / total);
            return chunk;
          })
          .pipe(sink);
    } finally {
      await sink.close();
    }
    return file.path;
  }

  /// Hands the downloaded installer to the OS's own handler for it — the
  /// same as tapping a downloaded .apk in Files on Android, or
  /// double-clicking a downloaded Setup.exe on Windows. Either OS takes
  /// it from there: Android's package installer, or Inno Setup's wizard
  /// (which closes this app to replace its files, then reopens it — see
  /// CloseApplications in windows/installer/uchi.iss).
  static Future<void> install(String installerPath) =>
      OpenFilex.open(installerPath);
}

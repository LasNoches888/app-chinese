import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// One available update: enough to show it and fetch it.
class AppUpdate {
  final int buildNumber;
  final String apkUrl;
  final int? apkSizeBytes;

  const AppUpdate({
    required this.buildNumber,
    required this.apkUrl,
    this.apkSizeBytes,
  });
}

/// Checks GitHub Releases for a newer build than the one currently
/// running, and installs it.
///
/// There is no app store here — every release is this repo's CI
/// uploading an APK to GitHub (see .github/workflows/build-apk.yml), so
/// "is there an update" is answerable without any server of the app's
/// own. The release tag is the CI run number, which only ever goes up,
/// so comparing versions is a plain integer diff rather than a semver
/// parse.
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

  /// Checks for an update.
  ///
  /// Returns null when the check succeeded and the running build is
  /// already current — a real answer, not a failure. Anything that stops
  /// the check from completing (no connection, GitHub down, an
  /// unparseable response) throws instead, so the caller can tell "you're
  /// current" from "couldn't find out" and say so.
  ///
  /// [client] and [localBuildNumber] are test seams — production callers
  /// never pass them, and get a real HTTP client and the actual installed
  /// build number.
  static Future<AppUpdate?> checkForUpdate({
    http.Client? client,
    int? localBuildNumber,
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

    final assets = release['assets'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? apk;
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      if ((map['name'] as String? ?? '').endsWith('.apk')) {
        apk = map;
        break;
      }
    }
    if (apk == null) {
      throw const FormatException('Release has no .apk asset');
    }

    return AppUpdate(
      buildNumber: remoteBuild,
      apkUrl: apk['browser_download_url'] as String,
      apkSizeBytes: apk['size'] as int?,
    );
  }

  /// Downloads [update]'s APK to a private cache file, reporting progress
  /// as a 0–1 fraction when the server states a size (GitHub always does
  /// for release assets, so this is effectively always available).
  ///
  /// [client] and [saveDir] are test seams, same as in [checkForUpdate].
  static Future<String> download(
    AppUpdate update, {
    void Function(double fraction)? onProgress,
    http.Client? client,
    Directory? saveDir,
  }) async {
    final request = http.Request('GET', Uri.parse(update.apkUrl));
    final response = await (client ?? http.Client()).send(request);
    if (response.statusCode != 200) {
      throw HttpException('Скачивание не удалось: ${response.statusCode}');
    }

    final total = response.contentLength ?? update.apkSizeBytes ?? 0;
    var received = 0;

    final dir = saveDir ?? await getTemporaryDirectory();
    // Named after the build it holds, so a second download doesn't race
    // a first one still being read by the installer, and a stale file
    // from an old check is never mistaken for a fresh one.
    final file = File('${dir.path}/uchi-update-${update.buildNumber}.apk');
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

  /// Hands the downloaded APK to Android's own installer — the same flow
  /// as tapping a downloaded APK in Files. The OS handles the "allow
  /// installs from this app" prompt itself the first time it's needed.
  static Future<void> install(String apkPath) => OpenFilex.open(apkPath);
}

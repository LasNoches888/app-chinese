import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_chinese/services/app_update_service.dart';

/// There's no app store here — updates are this repo's own GitHub
/// Releases, one asset per platform attached to the same tagged release
/// (an .apk for Android, an installer exe for Windows — see
/// build-apk.yml), and comparing versions is a plain integer diff on the
/// CI run number rather than a semver parse (see AppUpdateService).
/// These pin down that comparison, the per-platform asset match, and the
/// failure/no-update split it depends on, using a mock HTTP client
/// rather than the real GitHub API — a unit test hitting the network
/// would be slow, flaky, and prove nothing about this logic that a fixed
/// response can't.
void main() {
  http.Response releaseResponse({
    required String tag,
    List<Map<String, Object?>> assets = const [],
  }) => http.Response(jsonEncode({'tag_name': tag, 'assets': assets}), 200);

  Map<String, Object?> asset({
    required String name,
    String url = 'https://example.com/download',
    int size = 12345,
  }) => {'name': name, 'browser_download_url': url, 'size': size};

  group('checkForUpdate', () {
    test('a higher remote build is reported as available', () async {
      final client = MockClient(
        (_) async => releaseResponse(
          tag: 'build-42',
          assets: [asset(name: 'app-release.apk')],
        ),
      );

      final update = await AppUpdateService.checkForUpdate(
        client: client,
        localBuildNumber: 10,
        assetSuffix: '.apk',
      );

      expect(update, isNotNull);
      expect(update!.buildNumber, 42);
      expect(update.assetUrl, 'https://example.com/download');
    });

    test('an equal or lower remote build reports no update', () async {
      final client = MockClient(
        (_) async => releaseResponse(
          tag: 'build-10',
          assets: [asset(name: 'app-release.apk')],
        ),
      );

      expect(
        await AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 10,
          assetSuffix: '.apk',
        ),
        isNull,
      );
    });

    test(
      'picks the Windows installer when asked for the Windows suffix',
      () async {
        // Both assets present in the same release — a Windows client must
        // not grab the .apk (which it couldn't do anything with anyway).
        final client = MockClient(
          (_) async => releaseResponse(
            tag: 'build-7',
            assets: [
              asset(
                name: 'app-release.apk',
                url: 'https://example.com/app-release.apk',
              ),
              asset(
                name: 'UchiSetup.exe',
                url: 'https://example.com/UchiSetup.exe',
              ),
            ],
          ),
        );

        final update = await AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
          assetSuffix: 'Setup.exe',
        );

        expect(update!.assetName, 'UchiSetup.exe');
        expect(update.assetUrl, 'https://example.com/UchiSetup.exe');
      },
    );

    test('a release missing this platform\'s asset is a failure', () async {
      // Not "no update" — a release that only shipped an .apk this run
      // (say the Windows job failed) has to read as "couldn't check" on
      // Windows, not silently as "you're current".
      final client = MockClient(
        (_) async => releaseResponse(
          tag: 'build-9',
          assets: [asset(name: 'app-release.apk')],
        ),
      );

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
          assetSuffix: 'Setup.exe',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a non-200 response is a failure, not "no update"', () async {
      final client = MockClient((_) async => http.Response('', 500));

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
          assetSuffix: '.apk',
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('a tag with no number in it is a failure', () async {
      final client = MockClient(
        (_) async => releaseResponse(
          tag: 'latest',
          assets: [asset(name: 'app-release.apk')],
        ),
      );

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
          assetSuffix: '.apk',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('the request carries a User-Agent, or GitHub rejects it', () async {
      String? seenUserAgent;
      final client = MockClient((request) async {
        seenUserAgent = request.headers['User-Agent'];
        return releaseResponse(
          tag: 'build-5',
          assets: [asset(name: 'app-release.apk')],
        );
      });

      await AppUpdateService.checkForUpdate(
        client: client,
        localBuildNumber: 1,
        assetSuffix: '.apk',
      );

      expect(seenUserAgent, isNotNull);
      expect(seenUserAgent, isNotEmpty);
    });
  });

  group('download', () {
    test(
      'writes the response body to a file under the given directory',
      () async {
        final bytes = List<int>.generate(500, (i) => i % 256);
        final client = MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {'content-length': '${bytes.length}'},
          ),
        );
        final dir = await Directory.systemTemp.createTemp('update_test');
        addTearDown(() => dir.delete(recursive: true));

        final path = await AppUpdateService.download(
          const AppUpdate(
            buildNumber: 7,
            assetName: 'app-release.apk',
            assetUrl: 'https://example.com/x.apk',
          ),
          client: client,
          saveDir: dir,
        );

        final file = File(path);
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), bytes);
        expect(path, contains('7'));
        expect(path, endsWith('.apk'));
      },
    );

    test('keeps the Windows installer\'s .exe extension', () async {
      // Windows decides how to open a file by its extension — saved
      // without one, a downloaded Setup.exe just wouldn't run.
      final bytes = [1, 2, 3];
      final client = MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-length': '${bytes.length}'},
        ),
      );
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));

      final path = await AppUpdateService.download(
        const AppUpdate(
          buildNumber: 3,
          assetName: 'UchiSetup.exe',
          assetUrl: 'https://example.com/UchiSetup.exe',
        ),
        client: client,
        saveDir: dir,
      );

      expect(path, endsWith('.exe'));
    });

    test('reports progress as the download completes', () async {
      final bytes = List<int>.filled(1000, 1);
      final client = MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-length': '${bytes.length}'},
        ),
      );
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));

      final seen = <double>[];
      await AppUpdateService.download(
        const AppUpdate(
          buildNumber: 1,
          assetName: 'app-release.apk',
          assetUrl: 'https://example.com/x.apk',
        ),
        client: client,
        saveDir: dir,
        onProgress: seen.add,
      );

      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      // Monotonic — progress should never run backwards.
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });

    test('a non-200 response fails rather than saving a broken file', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));

      expect(
        () => AppUpdateService.download(
          const AppUpdate(
            buildNumber: 1,
            assetName: 'app-release.apk',
            assetUrl: 'https://example.com/x.apk',
          ),
          client: client,
          saveDir: dir,
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('alreadyDownloaded', () {
    test('finds a completed download from an earlier attempt', () async {
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));
      const update = AppUpdate(
        buildNumber: 4,
        assetName: 'app-release.apk',
        assetUrl: 'https://example.com/x.apk',
        assetSizeBytes: 5,
      );

      final downloadedPath = await AppUpdateService.download(
        update,
        client: MockClient(
          (_) async => http.Response.bytes(
            [1, 2, 3, 4, 5],
            200,
            headers: {'content-length': '5'},
          ),
        ),
        saveDir: dir,
      );

      // Simulates a fresh process: nothing but the file on disk carries
      // over from the interrupted attempt.
      final found = await AppUpdateService.alreadyDownloaded(
        update,
        saveDir: dir,
      );
      expect(found, downloadedPath);
    });

    test('ignores a file that was never downloaded', () async {
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));

      final found = await AppUpdateService.alreadyDownloaded(
        const AppUpdate(
          buildNumber: 4,
          assetName: 'app-release.apk',
          assetUrl: 'https://example.com/x.apk',
          assetSizeBytes: 5,
        ),
        saveDir: dir,
      );
      expect(found, isNull);
    });

    test('rejects a truncated file left by an interrupted download', () async {
      // The exact failure this exists for: the process gets killed
      // mid-write, leaving a partial file under the name a completed
      // download would have used.
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/uchi-update-4.apk').writeAsBytes([1, 2]);

      final found = await AppUpdateService.alreadyDownloaded(
        const AppUpdate(
          buildNumber: 4,
          assetName: 'app-release.apk',
          assetUrl: 'https://example.com/x.apk',
          assetSizeBytes: 5,
        ),
        saveDir: dir,
      );
      expect(found, isNull);
    });
  });
}

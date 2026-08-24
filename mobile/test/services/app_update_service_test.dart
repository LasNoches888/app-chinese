import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_chinese/services/app_update_service.dart';

/// There's no app store here — updates are this repo's own GitHub
/// Releases, and comparing versions is a plain integer diff on the CI run
/// number rather than a semver parse (see AppUpdateService). These pin
/// down that comparison and the failure/no-update split it depends on,
/// using a mock HTTP client rather than the real GitHub API — a unit
/// test hitting the network would be slow, flaky, and prove nothing
/// about this logic that a fixed response can't.
void main() {
  http.Response releaseResponse({
    required String tag,
    List<Map<String, Object?>> assets = const [],
  }) => http.Response(jsonEncode({'tag_name': tag, 'assets': assets}), 200);

  Map<String, Object?> apkAsset({
    String name = 'app-release.apk',
    String url = 'https://example.com/app-release.apk',
    int size = 12345,
  }) => {'name': name, 'browser_download_url': url, 'size': size};

  group('checkForUpdate', () {
    test('a higher remote build is reported as available', () async {
      final client = MockClient(
        (_) async => releaseResponse(tag: 'build-42', assets: [apkAsset()]),
      );

      final update = await AppUpdateService.checkForUpdate(
        client: client,
        localBuildNumber: 10,
      );

      expect(update, isNotNull);
      expect(update!.buildNumber, 42);
      expect(update.apkUrl, 'https://example.com/app-release.apk');
    });

    test('an equal or lower remote build reports no update', () async {
      final client = MockClient(
        (_) async => releaseResponse(tag: 'build-10', assets: [apkAsset()]),
      );

      expect(
        await AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 10,
        ),
        isNull,
      );
    });

    test('a non-200 response is a failure, not "no update"', () async {
      final client = MockClient((_) async => http.Response('', 500));

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('a tag with no number in it is a failure', () async {
      final client = MockClient(
        (_) async => releaseResponse(tag: 'latest', assets: [apkAsset()]),
      );

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a release with no .apk asset is a failure', () async {
      // Otherwise "update available" would point at nothing installable.
      final client = MockClient(
        (_) async => releaseResponse(
          tag: 'build-99',
          assets: [
            {'name': 'source.zip', 'browser_download_url': '...', 'size': 1},
          ],
        ),
      );

      expect(
        () => AppUpdateService.checkForUpdate(
          client: client,
          localBuildNumber: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('the request carries a User-Agent, or GitHub rejects it', () async {
      String? seenUserAgent;
      final client = MockClient((request) async {
        seenUserAgent = request.headers['User-Agent'];
        return releaseResponse(tag: 'build-5', assets: [apkAsset()]);
      });

      await AppUpdateService.checkForUpdate(
        client: client,
        localBuildNumber: 1,
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
          const AppUpdate(buildNumber: 7, apkUrl: 'https://example.com/x.apk'),
          client: client,
          saveDir: dir,
        );

        final file = File(path);
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), bytes);
        expect(path, contains('7'));
      },
    );

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
        const AppUpdate(buildNumber: 1, apkUrl: 'https://example.com/x.apk'),
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
          const AppUpdate(buildNumber: 1, apkUrl: 'https://example.com/x.apk'),
          client: client,
          saveDir: dir,
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });
}

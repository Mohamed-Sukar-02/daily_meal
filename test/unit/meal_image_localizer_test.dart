import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:daily_meal/core/services/meal_image_localizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny valid-enough JPEG-ish payload; the localizer only checks the
/// `Content-Type` header, not magic bytes.
final _imageBytes = Uint8List.fromList(utf8.encode('FAKE-JPEG-BYTES'));

const _megabyte = 1024 * 1024;

void main() {
  late Directory docsDir;
  late List<http.BaseRequest> requestsMade;

  /// A streaming client that answers every request with [response].
  MockClient clientRespondingWith(http.StreamedResponse Function() response) {
    return MockClient.streaming((request, body) async {
      requestsMade.add(request);
      return response();
    });
  }

  http.StreamedResponse imageResponse({
    List<List<int>> chunks = const [],
    int? contentLength,
    String contentType = 'image/jpeg',
    int status = 200,
  }) {
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      status,
      headers: {'content-type': contentType},
      contentLength: contentLength,
    );
  }

  setUp(() {
    docsDir = Directory.systemTemp.createTempSync('meal_localizer_test');
    requestsMade = [];
    MealImageLocalizer.instance.documentsDirectoryResolver =
        () async => docsDir;
  });

  tearDown(() {
    MealImageLocalizer.instance.client = null;
    MealImageLocalizer.instance.documentsDirectoryResolver = null;
    MealImageLocalizer.customTrustedHosts = {};
    MealImageLocalizer.hostValidator = null;
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  });

  /// Deterministic target path the localizer derives for [url] (same scheme
  /// as production: sha1 of the URL inside `meal_images/`).
  String expectedTargetPath(String url) {
    final hash = sha1.convert(url.codeUnits).toString();
    return '${docsDir.path}/meal_images/img_$hash.jpg';
  }

  List<String> filesOnDisk() => docsDir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .toList();

  group('HTTPS enforcement', () {
    test('plain http:// URL is refused without any network request',
        () async {
      const url = 'http://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: [_imageBytes]));

      final result =
          await MealImageLocalizer.instance.localize(url);

      expect(result, url, reason: 'original URL must be kept as-is');
      expect(requestsMade, isEmpty, reason: 'no download may be attempted');
      expect(filesOnDisk(), isEmpty);
    });
  });

  group('Host allow-list', () {
    test('untrusted host is refused even over HTTPS', () async {
      const url = 'https://evil.example.com/victim.jpg';
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: [_imageBytes]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(requestsMade, isEmpty);
      expect(filesOnDisk(), isEmpty);
    });

    test('firebasestorage.app project subdomain is trusted', () async {
      const url = 'https://daily-meal000.firebasestorage.app/x.jpg';
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: [_imageBytes]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, isNot(url));
      expect(File(result!).existsSync(), isTrue);
    });

    test('customTrustedHosts opens an extra host at runtime', () async {
      const url = 'https://cdn.partner.example/photo.jpg';
      MealImageLocalizer.customTrustedHosts = {'cdn.partner.example'};
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: [_imageBytes]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, isNot(url));
      expect(File(result!).existsSync(), isTrue);
    });

    test('hostValidator override trusts a computed host', () async {
      const url = 'https://a.b/media/x.jpg';
      MealImageLocalizer.hostValidator = (uri) => uri.host == 'a.b';
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: [_imageBytes]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, isNot(url));
      expect(File(result!).existsSync(), isTrue);
    });
  });

  group('Response validation', () {
    test('non-image Content-Type (text/html) is refused', () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(
              chunks: [_imageBytes], contentType: 'text/html'));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(filesOnDisk(), isEmpty,
          reason: 'no file or temp artefact may persist');
    });

    test('missing Content-Type is refused', () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(chunks: [_imageBytes], contentType: ''));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(filesOnDisk(), isEmpty);
    });

    test('non-200 status is refused', () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(chunks: [_imageBytes], status: 404));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(filesOnDisk(), isEmpty);
    });
  });

  group('Size ceiling (5 MB)', () {
    test('declared Content-Length above the cap aborts before streaming',
        () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(contentLength: 6 * _megabyte));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(filesOnDisk(), isEmpty,
          reason: 'cap hit from headers alone must not touch the disk');
    });

    test('stream that exceeds the cap is aborted and the .tmp is cleaned up',
        () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      final oversized = List.generate(6, (_) => List<int>.filled(_megabyte, 1));
      MealImageLocalizer.instance.client =
          clientRespondingWith(() => imageResponse(chunks: oversized));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, url);
      expect(filesOnDisk(), isEmpty,
          reason: 'no truncated .tmp or final file may persist');
    });
  });

  group('Happy path (atomic staging)', () {
    test('valid HTTPS image streams to .tmp then renames onto the target',
        () async {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(chunks: [
                _imageBytes.sublist(0, 4),
                _imageBytes.sublist(4),
              ]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, isNot(url));
      expect(result, expectedTargetPath(url));
      final saved = File(result!);
      expect(saved.existsSync(), isTrue);
      expect(await saved.length(), _imageBytes.length);
      expect(await saved.readAsBytes(), _imageBytes);
      expect(
        filesOnDisk().where((p) => p.endsWith('.tmp')),
        isEmpty,
        reason: 'staging .tmp must be consumed by the rename',
      );
      expect(requestsMade.length, 1);
    });
  });

  group('Idempotency', () {
    test('existing non-empty target short-circuits without any request',
        () async {
      const url = 'https://firebasestorage.googleapis.com/v0/b/x.jpg';
      final target = File(expectedTargetPath(url))
        ..createSync(recursive: true)
        ..writeAsBytesSync(utf8.encode('ALREADY-DOWNLOADED'));
      MealImageLocalizer.instance.client = clientRespondingWith(
          () => imageResponse(chunks: [_imageBytes]));

      final result = await MealImageLocalizer.instance.localize(url);

      expect(result, target.path);
      expect(requestsMade, isEmpty,
          reason: 'cached file must be returned without touching the network');
      expect(target.readAsBytesSync(), utf8.encode('ALREADY-DOWNLOADED'),
          reason: 'existing bytes must not be overwritten');
    });
  });
}

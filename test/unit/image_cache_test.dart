import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configureImageCache configures imageCache within adaptive bounds', () {
    configureImageCache();
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.maximumSize, anyOf(500, 900));
    expect(cache.maximumSizeBytes, anyOf(96 * 1024 * 1024, 160 * 1024 * 1024));
  });
}

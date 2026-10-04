import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../widgets/meal_image.dart';

/// The colour a picture is mostly made of.
///
/// The home recommendation card takes its panel hue from the dish photograph
/// beside it, which is what makes three recommendations read as three meals
/// rather than three copies of one card. Only the hue is asked of the picture;
/// the caller decides how deep or how pale to render it, so a photo that
/// happens to be mid-grey cannot produce a panel the dish name disappears into.
///
/// Results are cached per source for the life of the process: a photo's colour
/// does not change, and the list rebuilds on every favourite toggle.
class DominantColour {
  DominantColour._();

  /// Side of the sample grid the histogram is built from.
  ///
  /// The picture is decoded at full size on purpose. Asking the codec for a
  /// 48px thumbnail looks like the cheap option, but a 1024→48 request is not a
  /// size libpng can decimate to, so the pixels come back gathered rather than
  /// averaged — one sample per 21×21 block — and the histogram then describes
  /// a handful of scattered pixels instead of the dish. Sampling a grid off the
  /// full decode costs one extra decode per photo (cached for the process, and
  /// it never blocks the card, which paints on its fallback tone first) and
  /// actually looks at the whole picture.
  static const int _probeStride = 8;

  /// Pixels this far apart in all three channels are treated as one shade.
  static const int _bucketShift = 4;

  /// Below this channel spread a pixel is grey, and outside the luminance
  /// bounds it is shadow or highlight. None of those carry a usable hue, so a
  /// photo of food on a black slate cannot tint the panel black.
  static const int _minChroma = 22;
  static const int _minLuminance = 24;
  static const int _maxLuminance = 238;

  static final Map<String, Future<Color?>> _pending = {};

  /// The dominant colour of [source], or `null` when there is no photo, it
  /// cannot be read, or everything in it is grey.
  ///
  /// Never throws: a card that cannot find a hue falls back to the tone chosen
  /// for meals without a photo.
  static Future<Color?> of(String? source) {
    final value = source?.trim() ?? '';
    if (value.isEmpty) return Future<Color?>.value();
    return _pending.putIfAbsent(value, () => _extract(value));
  }

  static Future<Color?> _extract(String source) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final bytes = await _bytesFor(source);
      if (bytes == null) return null;
      codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return _dominant(data.buffer.asUint8List(), image.width, image.height);
    } catch (error) {
      // A tint is decoration; it must never be the reason a card is broken.
      debugPrint('DominantColour: $source could not be read ($error)');
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static Future<Uint8List?> _bytesFor(String source) async {
    switch (MealImageResolver.resolve(source)) {
      case MealImageSource.none:
        return null;
      case MealImageSource.network:
        final response = await http
            .get(Uri.parse(source))
            .timeout(const Duration(seconds: 10));
        return response.statusCode == 200 ? response.bodyBytes : null;
      case MealImageSource.asset:
        final data = await rootBundle.load(MealImageResolver.assetKey(source));
        return data.buffer.asUint8List();
      case MealImageSource.file:
        if (!MealImageResolver.isReadableFile(source)) return null;
        return File(source).readAsBytes();
    }
  }

  /// The busiest chromatic bucket, weighted so a large patch of dull background
  /// loses to a small, saturated pile of food.
  ///
  /// Walks a grid rather than every pixel: at [_probeStride] apart a 1024×768
  /// photo still yields ~1,500 samples spread evenly over it, which is more
  /// than a colour average needs and keeps the whole pass off the order of a
  /// million iterations.
  static Color? _dominant(Uint8List px, int width, int height) {
    final buckets = <int, _Bucket>{};
    for (var y = 0; y < height; y += _probeStride) {
      final row = y * width;
      for (var x = 0; x < width; x += _probeStride) {
        final i = (row + x) * 4;
        if (i + 3 >= px.length) continue;
        final r = px[i], g = px[i + 1], b = px[i + 2];
        if (px[i + 3] < 128) continue;
        final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (max - min < _minChroma) continue;
        if (max < _minLuminance || min > _maxLuminance) continue;
        final key =
            ((r >> _bucketShift) << 8) |
            ((g >> _bucketShift) << 4) |
            (b >> _bucketShift);
        buckets.putIfAbsent(key, () => _Bucket()).add(r, g, b, max - min);
      }
    }

    _Bucket? best;
    for (final bucket in buckets.values) {
      if (best == null || bucket.score > best.score) best = bucket;
    }
    if (best == null) return null;
    return Color.fromARGB(255, best.redAvg, best.greenAvg, best.blueAvg);
  }
}

class _Bucket {
  int _count = 0;
  int _red = 0;
  int _green = 0;
  int _blue = 0;
  int _chroma = 0;

  void add(int r, int g, int b, int chroma) {
    _count++;
    _red += r;
    _green += g;
    _blue += b;
    _chroma += chroma;
  }

  /// Population × saturation, with the population square-rooted so a huge dull
  /// area cannot outright beat a modest, vivid one.
  double get score =>
      _count == 0 ? 0 : math.sqrt(_count) * (0.25 + _chroma / _count / 255);

  int get redAvg => _red ~/ _count;
  int get greenAvg => _green ~/ _count;
  int get blueAvg => _blue ~/ _count;
}

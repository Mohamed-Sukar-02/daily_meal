import 'dart:io';

import 'package:flutter/material.dart';

/// Where a meal photo should be loaded from.
///
/// `Meals.photoPath` is a single text column, but three different kinds of
/// values end up in it:
///  * `none`    – the meal has no photo at all (null / empty string).
///  * `network` – an `http(s)` URL. Meals downloaded from the Firebase cloud
///                vault store `CloudMeal.imageUrl` straight into `photoPath`.
///  * `file`    – an absolute path of a photo picked on-device (image_picker).
///  * `asset`   – a bundled asset path (`assets/...`), used for the static
///                placeholder photos shipped inside the app.
enum MealImageSource { none, network, file, asset }

/// Pure resolution helpers for [MealImage]. Kept separate from the widget so
/// they can be unit-tested without pumping any UI.
class MealImageResolver {
  const MealImageResolver._();

  /// Classifies a raw `photoPath` value without touching the filesystem.
  static MealImageSource resolve(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return MealImageSource.none;
    if (isRemote(value)) return MealImageSource.network;
    if (isAsset(value)) return MealImageSource.asset;
    return MealImageSource.file;
  }

  /// `true` when the value points at a remote (Firebase Storage / CDN) image.
  static bool isRemote(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  /// `true` when the value points at a photo bundled with the app.
  static bool isAsset(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('assets/') || lower.startsWith('asset:');
  }

  /// Normalises an asset reference so both `assets/x.png` and `asset:assets/x.png`
  /// resolve to the same key.
  static String assetKey(String value) {
    return value.startsWith('asset:') ? value.substring(6) : value;
  }

  /// Safely probes a local file. Never throws: malformed paths (e.g. paths
  /// containing NUL bytes) and missing/0-byte files all report `false`.
  static bool isReadableFile(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }
}

/// A defensive meal-photo widget.
///
/// It loads whichever source `photoPath` describes (network / file / asset) and
/// always degrades to [fallback] instead of throwing or showing a broken frame.
/// Visual styling is intentionally not baked in here: the caller passes the
/// fallback so the design system stays in one place.
class MealImage extends StatelessWidget {
  /// Raw value of `Meals.photoPath` (nullable, may be a URL, a path or junk).
  final String? photoPath;

  /// Shown while a remote image is downloading.
  final Widget? loading;

  /// Shown when there is no photo, or when loading/decoding fails.
  final Widget fallback;

  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Decoding hints – keeps memory sane for large Firebase photos.
  final int? cacheWidth;

  const MealImage({
    super.key,
    required this.photoPath,
    required this.fallback,
    this.loading,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final value = photoPath?.trim() ?? '';

    final Widget image = switch (MealImageResolver.resolve(value)) {
      MealImageSource.none => fallback,
      MealImageSource.asset => Image.asset(
          MealImageResolver.assetKey(value),
          height: height,
          width: width,
          fit: fit,
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      MealImageSource.network => Image.network(
          value,
          height: height,
          width: width,
          fit: fit,
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return loading ?? _defaultLoading(context, progress);
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      MealImageSource.file => _buildFileImage(value),
    };

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _buildFileImage(String value) {
    if (!MealImageResolver.isReadableFile(value)) return fallback;

    return Image.file(
      File(value),
      height: height,
      width: width,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  Widget _defaultLoading(BuildContext context, ImageChunkEvent progress) {
    final theme = Theme.of(context);
    final expected = progress.expectedTotalBytes;
    final value = expected == null || expected == 0
        ? null
        : (progress.cumulativeBytesLoaded / expected).clamp(0.0, 1.0);

    return Container(
      height: height,
      width: width,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, value: value),
      ),
    );
  }
}

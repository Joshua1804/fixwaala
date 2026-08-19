import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// A network image that degrades gracefully and caches to disk.
///
/// Bare `Image.network` has no `errorBuilder`, so a dead or expired Cloudinary
/// URL renders a red framework exception box in the middle of a list. It also
/// has no `cacheWidth`, so a 4 MP photo is decoded at full resolution to fill a
/// 72 px thumbnail. And it has no disk cache, so the same avatar is
/// re-downloaded from Cloudinary on every cold app start — [CachedNetworkImage]
/// keeps a disk-backed copy so a repeat view is instant and offline-tolerant.
class RemoteImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Decode width in logical pixels. Defaults to [width] when that is finite,
  /// which is the common case for thumbnails and grid tiles.
  final int? cacheWidth;

  const RemoteImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.card);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth =
        cacheWidth ??
        ((width != null && width!.isFinite)
            ? (width! * devicePixelRatio).round()
            : null);

    if (url == null || url!.trim().isEmpty) {
      return _frame(radius, const _RemoteImageFallback());
    }

    return _frame(
      radius,
      CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: decodeWidth,
        errorWidget: (_, _, _) => const _RemoteImageFallback(),
        placeholder: (_, _) => const _RemoteImagePlaceholder(),
      ),
    );
  }

  Widget _frame(BorderRadius radius, Widget child) => ClipRRect(
    borderRadius: radius,
    child: SizedBox(width: width, height: height, child: child),
  );
}

class _RemoteImageFallback extends StatelessWidget {
  const _RemoteImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.textHint.withValues(alpha: 0.12),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textHint,
          size: 24,
        ),
      ),
    );
  }
}

class _RemoteImagePlaceholder extends StatelessWidget {
  const _RemoteImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.textHint.withValues(alpha: 0.08));
  }
}

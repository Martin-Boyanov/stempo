import 'package:flutter/material.dart';

import '../theme/colors.dart';

class MediaCover extends StatelessWidget {
  const MediaCover({
    super.key,
    required this.imageAsset,
    required this.size,
    required this.borderRadius,
    this.overlay,
    this.child,
  });

  final String imageAsset;
  final double size;
  final double borderRadius;
  final Gradient? overlay;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isNetworkImage =
        imageAsset.startsWith('http://') || imageAsset.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isNetworkImage)
              Image.network(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackCover(),
              )
            else
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackCover(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    overlay ??
                    LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.18),
                        AppColors.background.withValues(alpha: 0.44),
                      ],
                    ),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            AppColors.background.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.textPrimary,
          size: 28,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BoviSenseBrand {
  static const String logoAssetPath = 'assets/images/logoApp.png';
}

class BoviSenseLogo extends StatelessWidget {
  const BoviSenseLogo({
    super.key,
    this.size = 132,
    this.showText = false,
    this.title = 'BoviSense',
    this.subtitle,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final double size;
  final bool showText;
  final String title;
  final String? subtitle;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!showText) {
      return SizedBox(
        width: size,
        height: size,
        child: _LogoImage(size: size, fit: fit, alignment: alignment),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: _LogoImage(size: size, fit: fit, alignment: alignment),
        ),
        if (showText) ...[
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class BoviSenseLogoCompact extends StatelessWidget {
  const BoviSenseLogoCompact({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.7,
        ),
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _LogoImage(
          size: size,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({
    required this.size,
    required this.fit,
    required this.alignment,
  });

  final double size;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      BoviSenseBrand.logoAssetPath,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.primaryLight,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.primary,
            size: size * 0.35,
          ),
        );
      },
    );
  }
}

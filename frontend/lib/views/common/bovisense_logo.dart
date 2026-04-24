import 'package:flutter/material.dart';

class BoviSenseBrand {
  static const String logoAssetPath = 'assets/images/logoApp.png';
}

class BoviSenseLogo extends StatelessWidget {
  const BoviSenseLogo({
    super.key,
    this.size = 132,
    this.showText = false,
    this.title = 'BoviSense-AI',
    this.subtitle,
  });

  final double size;
  final bool showText;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: _LogoImage(size: size),
        ),
        if (showText) ...[
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D4228),
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
                color: Color(0xFF5A7254),
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
        color: const Color(0x334A6741),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _LogoImage(size: size),
      ),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BoviSenseBrand.logoAssetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFE8F0E4),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: const Color(0xFF4A6741),
            size: size * 0.35,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

/// Official Truthworld App Logo Widget
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 32.0,
    this.showText = false,
    this.text = 'Truthworld',
    this.textSize,
    this.onTap,
    this.borderRadius,
  });

  final double size;
  final bool showText;
  final String text;
  final double? textSize;
  final VoidCallback? onTap;
  final double? borderRadius;

  static const String assetPath = 'assets/app_logo.png';

  @override
  Widget build(BuildContext context) {
    Widget logoImage = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Truthworld Logo',
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF38BDF8),
          borderRadius: BorderRadius.circular(borderRadius ?? (size * 0.25)),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );

    var content = logoImage;

    if (showText) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoImage,
          SizedBox(width: size * 0.35),
          Text(
            text,
            style: TextStyle(
              fontSize: textSize ?? (size * 0.65),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

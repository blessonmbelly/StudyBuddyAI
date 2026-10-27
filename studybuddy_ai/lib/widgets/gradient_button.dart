import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final Gradient gradient;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 50.0,
    this.width,
    this.borderRadius,
    this.gradient = AppColors.primaryGradient,
    this.boxShadow,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(9999);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: effectiveBorderRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: effectiveBorderRadius,
          onTap: onPressed,
          child: Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

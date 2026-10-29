import 'package:flutter/material.dart';

/// A reusable bottom bar container that respects system navigation bars
/// (Android 3-button navigation, gesture navigation, and iOS Home indicator).
///
/// Features:
/// - Background color extends to the bottom screen edge (behind system buttons).
/// - Content is safely padded above system buttons via [SafeArea].
/// - If gesture navigation is enabled (0 bottom inset), content sits naturally
///   at the bottom without extra blank space.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
    this.showShadow = true,
    this.border,
  });

  final Widget child;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final bool showShadow;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

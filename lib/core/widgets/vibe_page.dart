import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VibePage extends StatelessWidget {
  const VibePage({
    required this.child,
    this.bottomNavigationBar,
    this.useGradient = true,
    super.key,
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = useGradient
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                AppColors.background,
                Color(0xFFF1F2F5),
              ],
            ),
          )
        : const BoxDecoration(color: AppColors.background);

    return Scaffold(
      extendBody: false,
      backgroundColor: AppColors.background,
      bottomNavigationBar: bottomNavigationBar,
      body: DecoratedBox(
        decoration: decoration,
        child: SafeArea(
          bottom: bottomNavigationBar == null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

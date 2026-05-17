import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LoadingWaveform extends StatefulWidget {
  const LoadingWaveform({super.key});

  @override
  State<LoadingWaveform> createState() => _LoadingWaveformState();
}

class _LoadingWaveformState extends State<LoadingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(11, (index) {
            final phase = ((index % 5) + 1) / 5;
            final height =
                18 + (42 * ((_controller.value - phase).abs() - 0.5).abs());
            return Container(
              width: 6,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index.isEven ? AppColors.primary : AppColors.orange,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}

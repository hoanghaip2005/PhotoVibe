import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final appState = ref.read(appStateProvider);
      if (!appState.onboardingCompleted) {
        context.go('/onboarding');
      } else if (!appState.authPromptCompleted) {
        context.go('/login');
      } else if (!appState.musicProfileCompleted) {
        context.go('/music-setup');
      } else {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VibePage(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.pink, AppColors.orange],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.camera_fill,
                color: Colors.white,
                size: 48,
              ),
            ).animate().scale(duration: 520.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'VibeLens',
              style: Theme.of(context).textTheme.headlineLarge,
            ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.18),
            const SizedBox(height: 8),
            Text(
              'Turn moments into moods.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 320.ms),
            const SizedBox(height: 34),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

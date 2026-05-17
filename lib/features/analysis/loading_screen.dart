import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_waveform.dart';
import '../../core/widgets/media_preview.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  var _step = 0;
  Timer? _timer;

  static const _steps = [
    'Đọc khung cảnh',
    'Phân tích màu sắc',
    'Tìm playlist phù hợp',
    'Tạo vibe card',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 520), (timer) {
      if (!mounted) return;
      setState(() => _step = (_step + 1).clamp(0, _steps.length - 1));
    });
    unawaited(_runAnalysis());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final result = await ref.read(appStateProvider).analyzeCurrentCapture();
    if (!mounted) return;
    if (result == null) {
      context.go('/preview');
    } else {
      context.go('/result/${result.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final capture = appState.currentCapture;
    if (capture == null) {
      return VibePage(
        child: EmptyState(
          icon: CupertinoIcons.exclamationmark_circle_fill,
          title: 'Không có media',
          message: 'Hãy quay lại Capture để chọn ảnh.',
          actionLabel: 'Quay lại',
          onAction: () => context.go('/capture'),
        ),
      );
    }

    return VibePage(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaPreview(
            capture: capture,
            mediaBytes: appState.currentMediaBytes,
            height: double.infinity,
          ),
          ColoredBox(color: AppColors.navy.withValues(alpha: 0.28)),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.separator.withValues(alpha: 0.60),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đang đọc mood của bạn...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    const LoadingWaveform(),
                    const SizedBox(height: 18),
                    for (var i = 0; i < _steps.length; i++)
                      _LoadingStep(
                        label: _steps[i],
                        active: i == _step,
                        done: i < _step,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

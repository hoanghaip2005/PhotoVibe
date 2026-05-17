import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  static const _slides = [
    _Slide(
      eyebrow: 'VibeLens Capture',
      title: 'Khoảnh khắc vào nhạc.',
      body:
          'Chọn một bức ảnh. VibeLens đọc ánh sáng, màu sắc và nhịp của khung hình để mở đầu một mood thật riêng.',
      icon: CupertinoIcons.camera_fill,
      accent: AppColors.blue,
      secondary: AppColors.green,
      previewTitle: 'AM',
      previewSubtitle: 'Calm',
      metrics: [
        _Metric(label: 'Vibe', value: 'Calm'),
        _Metric(label: 'Tone', value: 'Warm'),
      ],
    ),
    _Slide(
      eyebrow: 'Vibe AI',
      title: 'Đọc mood, không đoán mò.',
      body:
          'AI mô tả vibe của ảnh, tạo quote và palette màu. Không chẩn đoán tâm lý, không suy diễn thông tin nhạy cảm.',
      icon: CupertinoIcons.sparkles,
      accent: AppColors.primary,
      secondary: AppColors.pink,
      previewTitle: 'City rain',
      previewSubtitle: 'Rain',
      metrics: [
        _Metric(label: 'Match', value: '92%'),
        _Metric(label: 'Tags', value: 'Rain'),
      ],
    ),
    _Slide(
      eyebrow: 'Music Profile',
      title: 'Playlist gần gu hơn.',
      body:
          'Sau onboarding, bạn chọn tuổi, giới tính tùy chọn và gu nhạc. Tất cả chỉ là tín hiệu mềm để gợi ý bài hát sát vibe hơn.',
      icon: CupertinoIcons.music_note_2,
      accent: AppColors.orange,
      secondary: AppColors.primary,
      previewTitle: 'Cafe',
      previewSubtitle: 'Lo-fi',
      metrics: [
        _Metric(label: 'Songs', value: '8'),
        _Metric(label: 'Taste', value: 'Soft'),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(appStateProvider).completeOnboarding();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VibePage(
      useGradient: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFBFAF7), Color(0xFFF3F1EC)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            children: [
              _TopBar(onSkip: _finish),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) => _SlidePage(
                    slide: _slides[index],
                    visible: index == _index,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _StepIndicator(length: _slides.length, index: _index),
              const SizedBox(height: 18),
              _PrimaryPillButton(
                label: _index == _slides.length - 1
                    ? 'Tạo hồ sơ nghe nhạc'
                    : 'Tiếp tục',
                icon: _index == _slides.length - 1
                    ? CupertinoIcons.person_badge_plus
                    : CupertinoIcons.arrow_right,
                onPressed: _next,
              ),
              const SizedBox(height: 12),
              const _CapabilityRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            CupertinoIcons.camera_fill,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'VibeLens',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: const Text('Bỏ qua'),
        ),
      ],
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.visible});

  final _Slide slide;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        final stageHeight = compact
            ? (constraints.maxHeight * 0.34).clamp(120.0, 190.0)
            : (constraints.maxHeight * 0.46).clamp(240.0, 340.0);
        return SingleChildScrollView(
          physics: compact
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: stageHeight,
                  child: _MomentStage(slide: slide, active: visible),
                ),
                SizedBox(height: compact ? 14 : 24),
                Text(
                  slide.eyebrow,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: slide.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: compact ? 26 : 34,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 4 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MomentStage extends StatelessWidget {
  const _MomentStage({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      scale: active ? 1 : 0.96,
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.92,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.separator.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          slide.accent.withValues(alpha: 0.92),
                          slide.secondary.withValues(alpha: 0.78),
                          const Color(0xFF111827),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.40),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: _PreviewBadge(
                      icon: slide.icon,
                      accent: slide.accent,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _PreviewPanel(slide: slide),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: accent, size: 25),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slide.previewTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slide.previewSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.metrics.first.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.length, required this.index});

  final int length;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: i == index ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.ink
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CapabilityChip(icon: CupertinoIcons.paintbrush_fill, label: 'Palette'),
        const SizedBox(width: 8),
        _CapabilityChip(icon: CupertinoIcons.quote_bubble_fill, label: 'Quote'),
        const SizedBox(width: 8),
        _CapabilityChip(icon: CupertinoIcons.music_note_2, label: 'Playlist'),
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.previewTitle,
    required this.previewSubtitle,
    required this.metrics,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final Color secondary;
  final String previewTitle;
  final String previewSubtitle;
  final List<_Metric> metrics;
}

class _Metric {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;
}

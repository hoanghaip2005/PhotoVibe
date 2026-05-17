import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/media_preview.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/analysis_preferences.dart';
import '../../state/app_state.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late final TextEditingController _hintController;
  AnalysisMode _mode = AnalysisMode.autoVibe;
  final Set<String> _moods = {};

  static const _moodOptions = [
    'Chill',
    'Buồn',
    'Dreamy',
    'Hype',
    'Romantic',
    'Hoài niệm',
    'Cinematic',
    'Healing',
  ];

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(appStateProvider).currentAnalysisPreferences;
    _hintController = TextEditingController(text: preferences.hint);
    _mode = preferences.mode;
    _moods.addAll(preferences.moodHints);
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final capture = appState.currentCapture;

    if (capture == null || !capture.hasMedia) {
      return VibePage(
        child: EmptyState(
          icon: CupertinoIcons.photo_on_rectangle,
          title: 'Chưa có media',
          message: 'Hãy chọn ảnh trước khi phân tích vibe.',
          actionLabel: 'Quay lại Capture',
          onAction: () => context.go('/capture'),
        ),
      );
    }

    return VibePage(
      child: Column(
        children: [
          _PreviewHeader(onBack: () => context.go('/capture')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: [
                MediaPreview(
                  capture: capture,
                  mediaBytes: appState.currentMediaBytes,
                  label: capture.label,
                  height: 320,
                ),
                if (appState.lastError != null) ...[
                  const SizedBox(height: 12),
                  _InlineError(message: appState.lastError!),
                ],
                const SizedBox(height: 18),
                _GroupedSection(
                  title: 'Goi y cho AI',
                  child: TextField(
                    controller: _hintController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText:
                          'Thêm cảm giác, bối cảnh hoặc gu bạn muốn ưu tiên',
                      prefixIcon: Icon(CupertinoIcons.text_bubble),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _GroupedSection(
                  title: 'Chế độ phân tích',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in AnalysisMode.values)
                        MoodChip(
                          label: mode.label,
                          selected: mode == _mode,
                          onTap: () => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _GroupedSection(
                  title: 'Mood hint',
                  subtitle:
                      'Hint chỉ là tín hiệu mềm. AI vẫn đọc vibe chính của ảnh.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mood in _moodOptions)
                        MoodChip(
                          label: mood,
                          selected: _moods.contains(mood),
                          onTap: () => setState(() {
                            if (_moods.contains(mood)) {
                              _moods.remove(mood);
                            } else {
                              _moods.add(mood);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BottomAnalyzeBar(
            onAnalyze: () {
              ref
                  .read(appStateProvider)
                  .updateAnalysisPreferences(
                    AnalysisPreferences(
                      hint: _hintController.text.trim(),
                      mode: _mode,
                      moodHints: _moods.toList(),
                    ),
                  );
              _confirmAndAnalyze(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndAnalyze(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi ảnh để AI phân tích?'),
        content: const Text(
          'VibeLens sẽ gửi ảnh này đến backend để AI phân tích vibe, màu sắc và bối cảnh. Ảnh gốc không lưu mặc định sau khi phân tích.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      context.go('/loading');
    }
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: onBack,
            icon: const Icon(CupertinoIcons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Xem trước',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _GroupedSection extends StatelessWidget {
  const _GroupedSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BottomAnalyzeBar extends StatelessWidget {
  const _BottomAnalyzeBar({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(
              color: AppColors.separator.withValues(alpha: 0.75),
              width: 0.7,
            ),
          ),
        ),
        child: FilledButton.icon(
          onPressed: onAnalyze,
          icon: const Icon(CupertinoIcons.sparkles),
          label: const Text('Phân tích vibe'),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.18)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.pink)),
    );
  }
}

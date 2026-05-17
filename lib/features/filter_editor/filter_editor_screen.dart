import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/media_preview.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/filter_preset.dart';
import '../../models/vibe_result.dart';
import '../../state/app_state.dart';

class FilterEditorScreen extends ConsumerStatefulWidget {
  const FilterEditorScreen({required this.resultId, super.key});

  final String resultId;

  @override
  ConsumerState<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends ConsumerState<FilterEditorScreen> {
  FilterPreset? _current;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final result = appState.resultById(widget.resultId);

    if (result == null) {
      return VibePage(
        child: EmptyState(
          icon: CupertinoIcons.slider_horizontal_3,
          title: 'Không tìm thấy filter',
          message: 'Filter editor cần một VibeResult hợp lệ.',
          actionLabel: 'Về Home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    _current ??= result.filters.first;
    final current = _current!;

    return VibePage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Quay lại',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Chỉnh filter',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                _BeforeAfterPreview(result: result, filter: current),
                const SizedBox(height: 18),
                Text('Preset', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: result.filters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final preset = result.filters[index];
                      final selected = preset.id == current.id;
                      return InkWell(
                        onTap: () => setState(() => _current = preset),
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 88,
                          child: Column(
                            children: [
                              Container(
                                height: 62,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: colorsFromHex(
                                      preset.paletteHex.take(3).toList(),
                                    ),
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Palette'),
                    const SizedBox(width: 10),
                    PaletteRow(paletteHex: current.paletteHex, size: 16),
                  ],
                ),
                const SizedBox(height: 18),
                _FilterSlider(
                  label: 'Brightness',
                  value: current.brightness,
                  min: -0.5,
                  max: 0.5,
                  onChanged: (value) =>
                      _update(current.copyWith(brightness: value)),
                ),
                _FilterSlider(
                  label: 'Contrast',
                  value: current.contrast,
                  min: -0.5,
                  max: 0.5,
                  onChanged: (value) =>
                      _update(current.copyWith(contrast: value)),
                ),
                _FilterSlider(
                  label: 'Saturation',
                  value: current.saturation,
                  min: -0.5,
                  max: 0.6,
                  onChanged: (value) =>
                      _update(current.copyWith(saturation: value)),
                ),
                _FilterSlider(
                  label: 'Warmth',
                  value: current.warmth,
                  min: -0.6,
                  max: 0.6,
                  onChanged: (value) =>
                      _update(current.copyWith(warmth: value)),
                ),
                _FilterSlider(
                  label: 'Fade',
                  value: current.fade,
                  min: 0,
                  max: 0.7,
                  onChanged: (value) => _update(current.copyWith(fade: value)),
                ),
                _FilterSlider(
                  label: 'Grain',
                  value: current.grain,
                  min: 0,
                  max: 0.7,
                  onChanged: (value) => _update(current.copyWith(grain: value)),
                ),
                _FilterSlider(
                  label: 'Vignette',
                  value: current.vignette,
                  min: 0,
                  max: 0.7,
                  onChanged: (value) =>
                      _update(current.copyWith(vignette: value)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.96),
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(appStateProvider).saveFilter(current);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã lưu preset.')),
                        );
                      }
                    },
                    icon: const Icon(CupertinoIcons.bookmark),
                    label: const Text('Lưu preset'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientButton(
                    label: 'Xuất ảnh',
                    icon: CupertinoIcons.share,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'VibeLens filter "${current.name}" cho ${result.vibeName}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _update(FilterPreset preset) {
    setState(() => _current = preset);
  }
}

class _BeforeAfterPreview extends ConsumerWidget {
  const _BeforeAfterPreview({required this.result, required this.filter});

  final VibeResult result;
  final FilterPreset filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Before', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              MediaPreview(
                capture: result.capture,
                mediaBytes: appState.currentMediaBytes,
                paletteHex: result.paletteHex,
                height: 190,
                label: 'Gốc',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('After', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    MediaPreview(
                      capture: result.capture,
                      mediaBytes: appState.currentMediaBytes,
                      paletteHex: filter.paletteHex,
                      height: 190,
                      label: filter.name,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _overlayColor(
                            filter,
                          ).withValues(alpha: _overlayOpacity(filter)),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: filter.vignette * 0.55,
                              ),
                            ],
                            radius: 0.82,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _overlayColor(FilterPreset filter) {
    if (filter.warmth >= 0) return AppColors.orange;
    return AppColors.blue;
  }

  double _overlayOpacity(FilterPreset filter) {
    return (filter.warmth.abs() + filter.fade + filter.saturation.abs()).clamp(
      0.08,
      0.42,
    );
  }
}

class _FilterSlider extends StatelessWidget {
  const _FilterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

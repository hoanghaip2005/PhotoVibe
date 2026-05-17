import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/media_preview.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/filter_preset.dart';
import '../../models/song.dart';
import '../../models/vibe_result.dart';
import '../../state/app_state.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.resultId, super.key});

  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final result = appState.resultById(resultId);

    if (result == null) {
      return VibePage(
        child: EmptyState(
          icon: CupertinoIcons.exclamationmark_circle,
          title: 'Không tìm thấy kết quả',
          message: 'Result này không còn trong bộ nhớ cục bộ.',
          actionLabel: 'Về Home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    return VibePage(
      useGradient: false,
      child: Column(
        children: [
          _ResultHeader(
            onBack: () => context.go('/home'),
            onShare: () => _share(result),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: [
                _VibeSummary(result: result),
                const SizedBox(height: 14),
                _PlaylistSection(result: result),
                const SizedBox(height: 14),
                _QuoteSection(result: result),
                const SizedBox(height: 14),
                _FilterSection(result: result),
                const SizedBox(height: 14),
                _StorySection(result: result),
              ],
            ),
          ),
          _StickyActions(result: result),
        ],
      ),
    );
  }

  static Future<void> _share(VibeResult result) {
    return SharePlus.instance.share(
      ShareParams(
        text:
            'VibeLens: ${result.vibeName}\n${result.quote.text}\nPlaylist: ${result.playlist.name}',
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Về Home',
            onPressed: onBack,
            icon: const Icon(CupertinoIcons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Vibe Check',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Chia sẻ',
            onPressed: onShare,
            icon: const Icon(CupertinoIcons.share),
          ),
        ],
      ),
    );
  }
}

class _VibeSummary extends ConsumerWidget {
  const _VibeSummary({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaBytes = ref.watch(appStateProvider).currentMediaBytes;
    final confidence = (result.confidence * 100).round();
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaPreview(
            capture: result.capture,
            mediaBytes: mediaBytes,
            paletteHex: result.paletteHex,
            height: 238,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Pill(label: 'AI Vibe', value: '$confidence%'),
              const Spacer(),
              PaletteRow(paletteHex: result.paletteHex),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.vibeName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            result.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in result.moodTags.take(6))
                MoodChip(label: tag, selected: tag == result.moodTags.first),
            ],
          ),
          const SizedBox(height: 16),
          _ConfidenceBar(value: result.confidence, label: 'Độ khớp vibe'),
        ],
      ),
    );
  }
}

class _PlaylistSection extends ConsumerWidget {
  const _PlaylistSection({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = result.playlist;
    final openUrl =
        playlist.spotifyUrl ?? playlist.songs.firstOrNull?.spotifySearchUrl;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Playlist dành cho bạn',
            actionLabel: 'Xem hết',
            onAction: () => context.go('/playlists/${playlist.id}'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _PaletteArtwork(paletteHex: playlist.paletteHex),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.songs.length} bài, mở bằng Spotify',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    PaletteRow(paletteHex: playlist.paletteHex),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final song in playlist.songs.take(4)) _SongRow(song: song),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: openUrl == null ? null : () => _openUrl(openUrl),
                  icon: const Icon(CupertinoIcons.arrow_up_right),
                  label: const Text('Mở Spotify'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Tạo lại playlist',
                onPressed: () async {
                  await ref
                      .read(appStateProvider)
                      .regeneratePlaylist(result.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã tạo lại playlist.')),
                    );
                  }
                },
                icon: const Icon(CupertinoIcons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSong(song),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.grouped,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.music_note_2,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${song.matchPercent}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteSection extends StatelessWidget {
  const _QuoteSection({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quote cho mood này'),
          const SizedBox(height: 10),
          Text(
            '"${result.quote.text}"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.quote.source,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: result.quote.text),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép quote.')),
                      );
                    }
                  },
                  icon: const Icon(CupertinoIcons.doc_on_doc),
                  label: const Text('Sao chép'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/filter-editor/${result.id}'),
                  icon: const Icon(CupertinoIcons.photo),
                  label: const Text('Gắn vào ảnh'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Gợi ý filter',
            actionLabel: 'Chỉnh sửa',
            onAction: () => context.go('/filter-editor/${result.id}'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: result.filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _FilterTile(
                  filter: result.filters[index],
                  selected: index == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({required this.filter, required this.selected});

  final FilterPreset filter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: _colorsFrom(filter.paletteHex)),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.separator,
                width: selected ? 2 : 0.8,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            filter.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorySection extends ConsumerWidget {
  const _StorySection({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(appStateProvider).currentMediaBytes;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Vibe card'),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 9 / 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaPreview(
                    capture: result.capture,
                    mediaBytes: bytes,
                    paletteHex: result.paletteHex,
                    height: double.infinity,
                    label: '',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VibeLens',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          result.vibeName,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.quote.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PaletteRow(paletteHex: result.paletteHex, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ResultScreen._share(result),
            icon: const Icon(CupertinoIcons.share),
            label: const Text('Tạo story / Chia sẻ'),
          ),
        ],
      ),
    );
  }
}

class _StickyActions extends ConsumerWidget {
  const _StickyActions({required this.result});

  final VibeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: result.isSaved
                    ? null
                    : () async {
                        await ref.read(appStateProvider).saveResult(result.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu vào diary.')),
                          );
                        }
                      },
                icon: Icon(
                  result.isSaved
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.bookmark,
                ),
                label: Text(result.isSaved ? 'Đã lưu' : 'Lưu'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => ResultScreen._share(result),
                icon: const Icon(CupertinoIcons.share),
                label: const Text('Chia sẻ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator.withValues(alpha: 0.65)),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: value,
            backgroundColor: AppColors.faint,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _PaletteArtwork extends StatelessWidget {
  const _PaletteArtwork({required this.paletteHex});

  final List<String> paletteHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: _colorsFrom(paletteHex)),
      ),
      child: const Icon(CupertinoIcons.music_note_2, color: Colors.white),
    );
  }
}

List<Color> _colorsFrom(List<String> paletteHex) {
  final colors = <Color>[];
  for (final hex in paletteHex.take(4)) {
    if (hex.length == 7) {
      colors.add(Color(int.parse('FF${hex.substring(1)}', radix: 16)));
    }
  }
  if (colors.length < 2) return const [AppColors.primary, AppColors.grouped];
  return colors;
}

Future<void> _openSong(Song song) async {
  final url = song.spotifyUrl ?? song.spotifySearchUrl;
  if (url == null) return;
  await _openUrl(url);
}

Future<void> _openUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

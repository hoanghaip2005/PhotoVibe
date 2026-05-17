import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/playlist.dart';
import '../../state/app_state.dart';

class PlaylistLibraryScreen extends ConsumerStatefulWidget {
  const PlaylistLibraryScreen({super.key});

  @override
  ConsumerState<PlaylistLibraryScreen> createState() =>
      _PlaylistLibraryScreenState();
}

class _PlaylistLibraryScreenState extends ConsumerState<PlaylistLibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final playlists = ref
        .watch(appStateProvider)
        .savedPlaylists
        .where(
          (playlist) =>
              playlist.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'playlists'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          Text('Playlist', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Tìm playlist đã lưu...',
              prefixIcon: Icon(CupertinoIcons.search),
            ),
          ),
          const SizedBox(height: 18),
          if (playlists.isEmpty)
            EmptyState(
              icon: CupertinoIcons.music_note_list,
              title: 'Chưa có playlist đã lưu',
              message:
                  'Sau khi phân tích vibe, hãy lưu kết quả để playlist xuất hiện ở đây.',
              actionLabel: 'Tạo vibe đầu tiên',
              onAction: () => context.go('/capture'),
            )
          else
            _PlaylistGroup(playlists: playlists),
        ],
      ),
    );
  }
}

class _PlaylistGroup extends StatelessWidget {
  const _PlaylistGroup({required this.playlists});

  final List<VibePlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          for (var i = 0; i < playlists.length; i++) ...[
            _PlaylistRow(playlist: playlists[i]),
            if (i < playlists.length - 1)
              const Divider(height: 1, indent: 96, color: AppColors.faint),
          ],
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist});

  final VibePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/playlists/${playlist.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
                    '${playlist.songs.length} bài, mở trong Spotify',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  PaletteRow(paletteHex: playlist.paletteHex),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: AppColors.tertiary),
          ],
        ),
      ),
    );
  }
}

class _PaletteArtwork extends StatelessWidget {
  const _PaletteArtwork({required this.paletteHex});

  final List<String> paletteHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: _colorsFrom(paletteHex)),
      ),
      child: const Icon(CupertinoIcons.music_note_2, color: Colors.white),
    );
  }
}

List<Color> _colorsFrom(List<String> paletteHex) {
  final colors = <Color>[];
  for (final hex in paletteHex.take(3)) {
    if (hex.length == 7) {
      colors.add(Color(int.parse('FF${hex.substring(1)}', radix: 16)));
    }
  }
  if (colors.length < 2) return const [AppColors.primary, AppColors.grouped];
  return colors;
}

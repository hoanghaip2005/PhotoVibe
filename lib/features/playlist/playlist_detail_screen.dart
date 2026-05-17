import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../state/app_state.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final playlist = appState.playlistById(playlistId);

    if (playlist == null) {
      return VibePage(
        child: EmptyState(
          icon: CupertinoIcons.music_note_list,
          title: 'Không tìm thấy playlist',
          message:
              'Playlist detail chỉ mở khi có dữ liệu từ Result hoặc Library.',
          actionLabel: 'Về Playlist',
          onAction: () => context.go('/playlists'),
        ),
      );
    }

    final sourceResultId = appState.results
        .where((item) => item.playlist.id == playlist.id)
        .firstOrNull
        ?.id;

    return VibePage(
      child: Column(
        children: [
          _Header(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/playlists'),
            onSave: () => ref.read(appStateProvider).savePlaylist(playlist.id),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              children: [
                _PlaylistHero(playlist: playlist),
                const SizedBox(height: 18),
                _ActionRow(
                  playlist: playlist,
                  onRegenerate: sourceResultId == null
                      ? null
                      : () async => ref
                            .read(appStateProvider)
                            .regeneratePlaylist(sourceResultId),
                ),
                const SizedBox(height: 18),
                _SongGroup(songs: playlist.songs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSave});

  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: onBack,
            icon: const Icon(CupertinoIcons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Playlist',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Lưu playlist',
            onPressed: onSave,
            icon: const Icon(CupertinoIcons.bookmark),
          ),
        ],
      ),
    );
  }
}

class _PlaylistHero extends StatelessWidget {
  const _PlaylistHero({required this.playlist});

  final VibePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _Artwork(paletteHex: playlist.paletteHex)),
        const SizedBox(height: 18),
        Text(playlist.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          playlist.description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PaletteRow(paletteHex: playlist.paletteHex),
            const Spacer(),
            Text(
              '${playlist.songs.length} bài',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in playlist.moodTags)
              MoodChip(label: tag, selected: tag == playlist.moodTags.first),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.playlist, required this.onRegenerate});

  final VibePlaylist playlist;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final openUrl =
        playlist.spotifyUrl ?? playlist.songs.firstOrNull?.spotifySearchUrl;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: openUrl == null ? null : () => _openUrl(openUrl),
            icon: const Icon(CupertinoIcons.arrow_up_right),
            label: const Text('Mở Spotify'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.spotify),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Tạo lại bài hát',
          onPressed: onRegenerate,
          icon: const Icon(CupertinoIcons.refresh),
        ),
      ],
    );
  }
}

class _SongGroup extends StatelessWidget {
  const _SongGroup({required this.songs});

  final List<Song> songs;

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
          for (var i = 0; i < songs.length; i++) ...[
            _SongDetailRow(song: songs[i], index: i + 1),
            if (i < songs.length - 1)
              const Divider(height: 1, indent: 72, color: AppColors.faint),
          ],
        ],
      ),
    );
  }
}

class _SongDetailRow extends StatelessWidget {
  const _SongDetailRow({required this.song, required this.index});

  final Song song;
  final int index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSong(song),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '$index',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.tertiary,
                  fontWeight: FontWeight.w700,
                ),
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
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
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

class _Artwork extends StatelessWidget {
  const _Artwork({required this.paletteHex});

  final List<String> paletteHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: _colorsFrom(paletteHex)),
      ),
      child: const Icon(
        CupertinoIcons.music_note_2,
        color: Colors.white,
        size: 72,
      ),
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

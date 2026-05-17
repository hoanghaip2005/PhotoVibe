import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/media_preview.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/vibe_result.dart';
import '../../state/app_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final recent = appState.savedResults.take(4).toList();

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'home'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          _HomeHeader(
            dateLabel: _todayLabel(),
            notificationCount: _notificationCount(appState),
            onNotifications: () => context.go('/notifications'),
          ),
          const SizedBox(height: 22),
          _CaptureModule(onStart: () => context.go('/capture')),
          const SizedBox(height: 12),
          _ActionList(
            actions: [
              _HomeAction(
                icon: CupertinoIcons.photo_on_rectangle,
                title: 'Tải ảnh lên',
                subtitle: 'Chọn ảnh có sẵn trong thư viện',
                onTap: () => context.go('/capture?tab=photos'),
              ),
              _HomeAction(
                icon: CupertinoIcons.slider_horizontal_3,
                title: 'Gu nghe nhạc',
                subtitle: 'Cập nhật ngôn ngữ, thể loại, độ tuổi',
                onTap: () => context.go('/music-setup'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _StatsStrip(
            vibes: appState.savedResults.length,
            playlists: appState.savedPlaylists.length,
            filters: appState.savedFilters.length,
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Vibe gần đây',
            actionLabel: recent.isEmpty ? null : 'Xem hết',
            onAction: () => context.go('/diary'),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            _RecentEmpty(onStart: () => context.go('/capture'))
          else
            SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final result = recent[index];
                  return _RecentVibeTile(
                    result: result,
                    onTap: () => context.go('/result/${result.id}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _todayLabel() {
    const weekdays = [
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
      'Chủ nhật',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day}/${now.month}';
  }

  int _notificationCount(VibeAppState appState) {
    var count = 1;
    if (!appState.userPreferences.isSignedIn) count++;
    if (appState.savedResults.isEmpty) count++;
    if (appState.savedPlaylists.isEmpty) count++;
    if (appState.lastError != null) count++;
    return count;
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.dateLabel,
    required this.notificationCount,
    required this.onNotifications,
  });

  final String dateLabel;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                'Bạn muốn nghe vibe nào?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        Badge(
          isLabelVisible: notificationCount > 0,
          label: Text('$notificationCount'),
          child: IconButton(
            tooltip: 'Thông báo',
            onPressed: onNotifications,
            icon: const Icon(CupertinoIcons.bell_fill),
          ),
        ),
      ],
    );
  }
}

class _CaptureModule extends StatelessWidget {
  const _CaptureModule({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 178,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, AppColors.grape, AppColors.coral],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 18,
                  top: 18,
                  child: Icon(
                    CupertinoIcons.camera_viewfinder,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Text(
                    'Ảnh, màu sắc và nhạc trong cùng một flow.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chụp khoảnh khắc',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'AI đọc ảnh, tạo vibe, filter và playlist cá nhân hóa từ kho nhạc Supabase.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(CupertinoIcons.arrow_right),
            label: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({required this.actions});

  final List<_HomeAction> actions;

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
          for (var i = 0; i < actions.length; i++) ...[
            _ActionRow(action: actions[i]),
            if (i < actions.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.faint),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.lavender,
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

class _RecentVibeTile extends StatelessWidget {
  const _RecentVibeTile({required this.result, required this.onTap});

  final VibeResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaPreview(
              capture: result.capture,
              paletteHex: result.paletteHex,
              height: 150,
            ),
            const SizedBox(height: 10),
            Text(
              result.vibeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            PaletteRow(paletteHex: result.paletteHex),
          ],
        ),
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.sparkles, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            'Chưa có vibe nào',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo vibe đầu tiên để diary bắt đầu có màu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onStart, child: const Text('Tạo vibe')),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.vibes,
    required this.playlists,
    required this.filters,
  });

  final int vibes;
  final int playlists;
  final int filters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Vibes',
            value: '$vibes',
            color: AppColors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Playlist',
            value: '$playlists',
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Filter',
            value: '$filters',
            color: AppColors.coral,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

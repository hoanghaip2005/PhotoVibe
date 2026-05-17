import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final items = _notificationsFor(appState);

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'home'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Quay lại',
                onPressed: () => context.go('/home'),
                icon: const Icon(CupertinoIcons.chevron_left),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thông báo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật trạng thái đọc.')),
                ),
                child: const Text('Đã đọc'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryCard(count: items.length),
          const SizedBox(height: 16),
          Text('Mới', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in items)
            _NotificationTile(item: item, onTap: () => context.go(item.route)),
        ],
      ),
    );
  }

  List<_VibeNotification> _notificationsFor(VibeAppState appState) {
    final items = <_VibeNotification>[];
    if (!appState.userPreferences.isSignedIn) {
      items.add(
        const _VibeNotification(
          icon: CupertinoIcons.person_badge_plus,
          color: AppColors.ink,
          title: 'Đăng nhập để giữ hồ sơ',
          body: 'Lưu email để hồ sơ, gu nhạc và diary dễ nhận diện hơn.',
          time: 'Vừa xong',
          route: '/login?next=notifications',
        ),
      );
    }
    if (appState.userPreferences.hasProductionMusicProfile) {
      items.add(
        const _VibeNotification(
          icon: CupertinoIcons.slider_horizontal_3,
          color: AppColors.primary,
          title: 'Gu nhạc đã sẵn sàng',
          body:
              'VibeLens sẽ dùng hồ sơ này làm tín hiệu mềm khi gợi ý bài hát.',
          time: 'Hôm nay',
          route: '/music-setup',
        ),
      );
    }
    if (appState.savedResults.isEmpty) {
      items.add(
        const _VibeNotification(
          icon: CupertinoIcons.camera_fill,
          color: AppColors.blue,
          title: 'Chụp vibe đầu tiên',
          body: 'Tải một ảnh lên để tạo quote, filter và playlist theo mood.',
          time: 'Gợi ý',
          route: '/capture',
        ),
      );
    } else {
      items.add(
        _VibeNotification(
          icon: CupertinoIcons.book_fill,
          color: AppColors.green,
          title: 'Diary đã có ${appState.savedResults.length} vibe',
          body: 'Mở lại các mood đã lưu và playlist đi kèm.',
          time: 'Đã lưu',
          route: '/diary',
        ),
      );
    }
    if (appState.savedPlaylists.isEmpty) {
      items.add(
        const _VibeNotification(
          icon: CupertinoIcons.music_note_list,
          color: AppColors.orange,
          title: 'Playlist library đang trống',
          body: 'Lưu một kết quả vibe để playlist xuất hiện trong thư viện.',
          time: 'Nhắc nhẹ',
          route: '/playlists',
        ),
      );
    }
    if (appState.lastError != null) {
      items.insert(
        0,
        _VibeNotification(
          icon: CupertinoIcons.exclamationmark_circle_fill,
          color: AppColors.pink,
          title: 'Có lỗi phân tích gần đây',
          body: appState.lastError!,
          time: 'Cần xem',
          route: '/preview',
        ),
      );
    }
    return items;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.ink,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count cập nhật',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tóm tắt tài khoản, diary và playlist của bạn.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final _VibeNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: item.color.withValues(alpha: 0.12),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          item.time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _VibeNotification {
  const _VibeNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final String route;
}

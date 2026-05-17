import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/user_preferences.dart';
import '../../state/app_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final prefs = appState.userPreferences;

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'profile'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          _ProfileHeader(
            prefs: prefs,
            onSignIn: () => context.go('/login?next=profile'),
          ),
          const SizedBox(height: 22),
          _StatsGroup(
            vibes: appState.savedResults.length,
            playlists: appState.savedPlaylists.length,
            filters: appState.savedFilters.length,
          ),
          const SizedBox(height: 16),
          _SpotifyCard(prefs: prefs),
          const SizedBox(height: 16),
          _PreferenceGroup(
            prefs: prefs,
            onEdit: () => context.go('/music-setup'),
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            appState: appState,
            prefs: prefs,
            onToggleDarkMode: (value) => ref
                .read(appStateProvider)
                .updateUserPreferences(prefs.copyWith(darkMode: value)),
          ),
          const SizedBox(height: 16),
          if (prefs.isSignedIn)
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(appStateProvider).signOutAccount();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đăng xuất tài khoản.')),
                  );
                }
              },
              icon: const Icon(CupertinoIcons.square_arrow_right),
              label: const Text('Đăng xuất'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go('/login?next=profile'),
              icon: const Icon(CupertinoIcons.person_badge_plus),
              label: const Text('Tạo hồ sơ'),
            ),
        ],
      ),
    );
  }

  static String ageLabel(String value) {
    return switch (value) {
      'teen' => 'Dưới 18',
      'young_adult' => '18-24',
      'adult' => '25-44',
      'middle_age' => '45-54',
      'senior' => '55+',
      _ => 'Chưa chọn tuổi',
    };
  }

  static String genderLabel(String value) {
    return switch (value) {
      'female' => 'Nữ',
      'male' => 'Nam',
      'non_binary' => 'Phi nhị nguyên',
      'other' => 'Khác',
      _ => 'Chưa chọn giới tính',
    };
  }

  static String eraLabel(String value) {
    return switch (value) {
      'trending' => 'Nhạc mới / trending',
      'modern' => 'Hiện đại',
      'balanced' => 'Cân bằng mới và cũ',
      'classic' => 'Nhạc cũ / classic',
      _ => 'Tùy mood',
    };
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.prefs, required this.onSignIn});

  final UserPreferences prefs;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: AppColors.ink,
          child: Icon(
            CupertinoIcons.person_fill,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefs.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                prefs.isSignedIn ? prefs.email : 'Hồ sơ trên thiết bị này',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!prefs.isSignedIn) ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: FilledButton.tonalIcon(
              onPressed: onSignIn,
              icon: const Icon(CupertinoIcons.person_badge_plus, size: 18),
              label: const Text('Hồ sơ'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(92, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsGroup extends StatelessWidget {
  const _StatsGroup({
    required this.vibes,
    required this.playlists,
    required this.filters,
  });

  final int vibes;
  final int playlists;
  final int filters;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          _ProfileStat(label: 'Vibes', value: '$vibes'),
          _ProfileStat(label: 'Playlists', value: '$playlists'),
          _ProfileStat(label: 'Filters', value: '$filters'),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({required this.prefs, required this.onEdit});

  final UserPreferences prefs;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final chips = [
      MoodChip(
        label: ProfileScreen.genderLabel(prefs.gender),
        selected: prefs.gender != 'unknown',
      ),
      MoodChip(
        label: ProfileScreen.ageLabel(prefs.ageGroup),
        selected: prefs.ageGroup != 'unknown',
      ),
      MoodChip(label: ProfileScreen.eraLabel(prefs.musicEraPreference)),
      for (final language in prefs.preferredLanguages)
        MoodChip(label: _languageLabel(language), selected: true),
      for (final genre in prefs.preferredGenres)
        MoodChip(label: genre, selected: true),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gu nghe nhạc',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Chỉnh')),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  String _languageLabel(String value) {
    return switch (value) {
      'vi' => 'Tiếng Việt',
      'en' => 'Tiếng Anh',
      'ko' => 'Hàn',
      'ja' => 'Nhật',
      _ => 'Không giới hạn',
    };
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.appState,
    required this.prefs,
    required this.onToggleDarkMode,
  });

  final VibeAppState appState;
  final UserPreferences prefs;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          _SettingTile(
            icon: CupertinoIcons.textformat,
            title: 'Ngôn ngữ quote',
            subtitle: prefs.quoteLanguage,
          ),
          const Divider(height: 1, indent: 62, color: AppColors.faint),
          _SettingTile(
            icon: CupertinoIcons.slider_horizontal_3,
            title: 'Filter đã lưu',
            subtitle: appState.savedFilters.isEmpty
                ? 'Chưa có preset'
                : '${appState.savedFilters.length} preset',
            trailing: appState.savedFilters.isEmpty
                ? null
                : PaletteRow(
                    paletteHex: appState.savedFilters.first.paletteHex,
                    size: 12,
                  ),
          ),
          const Divider(height: 1, indent: 62, color: AppColors.faint),
          _SettingTile(
            icon: CupertinoIcons.lock_shield_fill,
            title: 'Quyền riêng tư',
            subtitle:
                'Ảnh chỉ gửi đến backend AI sau khi bạn xác nhận ở màn Preview.',
          ),
          const Divider(height: 1, indent: 62, color: AppColors.faint),
          _SettingTile(
            icon: CupertinoIcons.sun_max_fill,
            title: 'Giao diện',
            subtitle: prefs.darkMode ? 'Dark mode' : 'Light mode',
            trailing: Switch(
              value: prefs.darkMode,
              onChanged: onToggleDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotifyCard extends StatelessWidget {
  const _SpotifyCard({required this.prefs});

  final UserPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: const Color(0xFF1DB954).withValues(alpha: 0.10),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.spotify,
            child: Icon(CupertinoIcons.music_note_2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mở trên Spotify',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Playlist mở bằng link/search URL từ backend. App không stream nhạc.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.arrow_up_right, color: AppColors.spotify),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.lavender,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

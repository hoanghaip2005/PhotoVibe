import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class MusicPreferenceSetupScreen extends ConsumerStatefulWidget {
  const MusicPreferenceSetupScreen({super.key});

  @override
  ConsumerState<MusicPreferenceSetupScreen> createState() =>
      _MusicPreferenceSetupScreenState();
}

class _MusicPreferenceSetupScreenState
    extends ConsumerState<MusicPreferenceSetupScreen> {
  late String _gender;
  late String _ageGroup;
  late String _era;
  late String _discovery;
  late bool _explicitAllowed;
  late Set<String> _genres;
  late Set<String> _languages;
  late final TextEditingController _artistsController;
  late final TextEditingController _songsController;

  static const _genderOptions = {
    'female': 'Nữ',
    'male': 'Nam',
    'non_binary': 'Phi nhị nguyên',
    'other': 'Khác',
    'unknown': 'Không muốn trả lời',
  };
  static const _ageOptions = {
    'teen': 'Dưới 18',
    'young_adult': '18-24',
    'adult': '25-44',
    'middle_age': '45-54',
    'senior': '55+',
    'unknown': 'Không muốn trả lời',
  };
  static const _genreOptions = [
    'Pop',
    'Indie',
    'Lo-fi',
    'Acoustic',
    'EDM',
    'Hip-hop/Rap',
    'R&B',
    'Rock',
    'Ballad',
    'V-Pop',
    'K-Pop',
    'Classical',
    'Jazz',
    'Bolero',
    'Nhạc Trịnh / oldies',
  ];
  static const _languageOptions = {
    'vi': 'Tiếng Việt',
    'en': 'Tiếng Anh',
    'ko': 'Hàn',
    'ja': 'Nhật',
    'unknown': 'Không quan trọng',
  };
  static const _eraOptions = {
    'trending': 'Nhạc mới / trending',
    'modern': 'Hiện đại nhưng không quá trend',
    'balanced': 'Cân bằng mới và cũ',
    'classic': 'Nhạc cũ / classic',
    'mood_based': 'Tùy mood',
  };

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appStateProvider).userPreferences;
    _gender = prefs.gender;
    _ageGroup = prefs.ageGroup;
    _era = prefs.musicEraPreference;
    _discovery = prefs.discoveryLevel;
    _explicitAllowed = prefs.explicitContentAllowed;
    _genres = prefs.preferredGenres.toSet();
    _languages = prefs.preferredLanguages.toSet();
    _artistsController = TextEditingController(
      text: prefs.favoriteArtists.join(', '),
    );
    _songsController = TextEditingController(
      text: prefs.favoriteSongs.join(', '),
    );
  }

  @override
  void dispose() {
    _artistsController.dispose();
    _songsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VibePage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              if (ref.read(appStateProvider).musicProfileCompleted)
                IconButton.filledTonal(
                  tooltip: 'Quay lại',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
              if (ref.read(appStateProvider).musicProfileCompleted)
                const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tạo hồ sơ nghe nhạc',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Một vài lựa chọn tự khai báo giúp VibeLens hiểu phạm vi gu nhạc trước khi phân tích ảnh. Giới tính và độ tuổi chỉ là tín hiệu mềm, không dùng để gán khuôn.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          _ChoiceSection(
            title: 'Bạn muốn VibeLens gọi hồ sơ này theo giới tính nào?',
            subtitle:
                'Có thể bỏ qua; gu nghe nhạc bạn chọn vẫn là tín hiệu chính.',
            children: [
              for (final entry in _genderOptions.entries)
                MoodChip(
                  label: entry.value,
                  selected: _gender == entry.key,
                  onTap: () => setState(() => _gender = entry.key),
                ),
            ],
          ),
          _ChoiceSection(
            title: 'Bạn thuộc nhóm tuổi nào?',
            children: [
              for (final entry in _ageOptions.entries)
                MoodChip(
                  label: entry.value,
                  selected: _ageGroup == entry.key,
                  onTap: () => setState(() => _ageGroup = entry.key),
                ),
            ],
          ),
          _ChoiceSection(
            title: 'Bạn thích nghe thể loại nào?',
            children: [
              for (final genre in _genreOptions)
                MoodChip(
                  label: genre,
                  selected: _genres.contains(genre),
                  onTap: () => setState(() {
                    _genres.contains(genre)
                        ? _genres.remove(genre)
                        : _genres.add(genre);
                  }),
                ),
            ],
          ),
          _ChoiceSection(
            title: 'Bạn thích nhạc mới, nhạc cũ hay tùy mood?',
            children: [
              for (final entry in _eraOptions.entries)
                MoodChip(
                  label: entry.value,
                  selected: _era == entry.key,
                  onTap: () => setState(() => _era = entry.key),
                ),
            ],
          ),
          _ChoiceSection(
            title: 'Bạn thường nghe nhạc ngôn ngữ nào?',
            children: [
              for (final entry in _languageOptions.entries)
                MoodChip(
                  label: entry.value,
                  selected: _languages.contains(entry.key),
                  onTap: () => setState(() {
                    _languages.contains(entry.key)
                        ? _languages.remove(entry.key)
                        : _languages.add(entry.key);
                  }),
                ),
            ],
          ),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                TextField(
                  controller: _artistsController,
                  decoration: const InputDecoration(
                    labelText: 'Nghệ sĩ yêu thích',
                    hintText: 'Nhập tên nghệ sĩ, cách nhau bằng dấu phẩy',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _songsController,
                  decoration: const InputDecoration(
                    labelText: 'Bài hát yêu thích',
                    hintText: 'Nhập tên bài hát, cách nhau bằng dấu phẩy',
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho phép bài hát explicit'),
                  subtitle: const Text(
                    'Nếu tắt, backend sẽ lọc bớt bài explicit khỏi playlist.',
                  ),
                  value: _explicitAllowed,
                  onChanged: (value) =>
                      setState(() => _explicitAllowed = value),
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(child: Text('Mức khám phá nhạc mới')),
                    DropdownButton<String>(
                      value: _discovery,
                      items: const [
                        DropdownMenuItem(
                          value: 'familiar',
                          child: Text('Quen thuộc'),
                        ),
                        DropdownMenuItem(
                          value: 'balanced',
                          child: Text('Cân bằng'),
                        ),
                        DropdownMenuItem(
                          value: 'adventurous',
                          child: Text('Khám phá'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _discovery = value ?? 'balanced'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GradientButton(
            label: 'Lưu và vào app',
            icon: CupertinoIcons.check_mark,
            onPressed: _save,
          ),
          TextButton(onPressed: _skip, child: const Text('Thiết lập sau')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final current = ref.read(appStateProvider).userPreferences;
    await ref
        .read(appStateProvider)
        .updateUserPreferences(
          current.copyWith(
            gender: _gender,
            ageGroup: _ageGroup,
            preferredGenres: _genres.toList(),
            preferredLanguages: _languages.toList(),
            musicEraPreference: _era,
            favoriteArtists: _csv(_artistsController.text),
            favoriteSongs: _csv(_songsController.text),
            explicitContentAllowed: _explicitAllowed,
            discoveryLevel: _discovery,
          ),
        );
    if (mounted) context.go('/home');
  }

  Future<void> _skip() async {
    await ref.read(appStateProvider).completeMusicProfileSetup();
    if (mounted) context.go('/home');
  }

  List<String> _csv(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

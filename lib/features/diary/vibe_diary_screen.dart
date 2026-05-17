import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mood_chip.dart';
import '../../core/widgets/palette_row.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/vibe_diary_entry.dart';
import '../../state/app_state.dart';

class VibeDiaryScreen extends ConsumerStatefulWidget {
  const VibeDiaryScreen({super.key});

  @override
  ConsumerState<VibeDiaryScreen> createState() => _VibeDiaryScreenState();
}

class _VibeDiaryScreenState extends ConsumerState<VibeDiaryScreen> {
  String _query = '';
  String? _selectedMood;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(appStateProvider).diaryEntries;
    final moods = entries.expand((entry) => entry.moodTags).toSet().take(10);
    final filtered = entries.where((entry) {
      final matchesQuery =
          _query.isEmpty ||
          entry.vibeName.toLowerCase().contains(_query.toLowerCase()) ||
          entry.quote.toLowerCase().contains(_query.toLowerCase());
      final matchesMood =
          _selectedMood == null || entry.moodTags.contains(_selectedMood);
      return matchesQuery && matchesMood;
    }).toList();

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'diary'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Text('Vibe Diary', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm vibe của bạn...',
              prefixIcon: Icon(CupertinoIcons.search),
            ),
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            EmptyState(
              icon: CupertinoIcons.book_fill,
              title: 'Chưa có vibe nào',
              message: 'Hãy chụp khoảnh khắc đầu tiên để nhật ký mood bắt đầu.',
              actionLabel: 'Chụp khoảnh khắc',
              onAction: () => context.go('/capture'),
            )
          else ...[
            _MonthlySummary(entries: entries),
            const SizedBox(height: 16),
            _MoodCalendar(entries: entries),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MoodChip(
                  label: 'Tất cả',
                  selected: _selectedMood == null,
                  onTap: () => setState(() => _selectedMood = null),
                ),
                for (final mood in moods)
                  MoodChip(
                    label: mood,
                    selected: _selectedMood == mood,
                    onTap: () => setState(() => _selectedMood = mood),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            for (final entry in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DiaryEntryCard(entry: entry),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.entries});

  final List<VibeDiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthEntries = entries
        .where(
          (entry) =>
              entry.date.month == now.month && entry.date.year == now.year,
        )
        .toList();
    final allMoods = monthEntries.expand((entry) => entry.moodTags).toList();
    final topMood = allMoods.isEmpty
        ? 'Chưa rõ'
        : allMoods
              .fold<Map<String, int>>({}, (map, mood) {
                map[mood] = (map[mood] ?? 0) + 1;
                return map;
              })
              .entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
    final avg = monthEntries.isEmpty
        ? 0
        : monthEntries
                  .map((entry) => entry.confidence)
                  .reduce((a, b) => a + b) /
              monthEntries.length;

    return GlassCard(
      child: Row(
        children: [
          _Stat(label: 'Vibes', value: '${monthEntries.length}'),
          _Stat(label: 'Mood chủ đạo', value: topMood),
          _Stat(label: 'Độ khớp TB', value: '${(avg * 100).round()}%'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MoodCalendar extends StatelessWidget {
  const _MoodCalendar({required this.entries});

  final List<VibeDiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(now.year, now.month);
    final activeDays = entries
        .where(
          (entry) =>
              entry.date.month == now.month && entry.date.year == now.year,
        )
        .map((entry) => entry.date.day)
        .toSet();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tháng ${now.month}/${now.year}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final day = index + 1;
              final active = activeDays.contains(day);
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.primary : AppColors.faint,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  const _DiaryEntryCard({required this.entry});

  final VibeDiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/result/${entry.resultId}'),
      borderRadius: BorderRadius.circular(22),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 74,
              height: 86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: entry.paletteHex
                      .take(3)
                      .map(
                        (hex) => Color(
                          int.parse('FF${hex.substring(1)}', radix: 16),
                        ),
                      )
                      .toList(),
                ),
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.vibeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.moodTags.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      PaletteRow(paletteHex: entry.paletteHex, size: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

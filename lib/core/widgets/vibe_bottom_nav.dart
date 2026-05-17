import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class VibeBottomNav extends StatelessWidget {
  const VibeBottomNav({required this.current, super.key});

  final String current;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem('home', 'Home', CupertinoIcons.house_fill, '/home'),
      _NavItem('capture', 'Capture', CupertinoIcons.camera_fill, '/capture'),
      _NavItem('diary', 'Diary', CupertinoIcons.book_fill, '/diary'),
      _NavItem(
        'playlists',
        'Playlist',
        CupertinoIcons.music_note_list,
        '/playlists',
      ),
      _NavItem('profile', 'Profile', CupertinoIcons.person_fill, '/profile'),
    ];

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.separator),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: _BottomNavButton(
                            item: item,
                            selected: current == item.id,
                            onTap: () => context.go(item.path),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.muted;
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.id, this.label, this.icon, this.path);

  final String id;
  final String label;
  final IconData icon;
  final String path;
}

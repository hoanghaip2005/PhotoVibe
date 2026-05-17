import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/capture_input.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';

class MediaPreview extends StatelessWidget {
  const MediaPreview({
    this.capture,
    this.mediaBytes,
    this.paletteHex = const ['#007AFF', '#5AC8FA', '#F5F5F7'],
    this.height = 220,
    this.label,
    super.key,
  });

  final CaptureInput? capture;
  final Uint8List? mediaBytes;
  final List<String> paletteHex;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFromHex(paletteHex.take(3).toList());
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaBytes != null)
              Image.memory(mediaBytes!, fit: BoxFit.cover)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors.length >= 2
                        ? colors
                        : const [AppColors.primary, AppColors.grouped],
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  Icon(_iconFor(capture?.type), color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label ?? capture?.label ?? _labelFor(capture?.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(CaptureType? type) {
    return CupertinoIcons.camera_fill;
  }

  String _labelFor(CaptureType? type) {
    return 'Khoảnh khắc của bạn';
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/vibe_bottom_nav.dart';
import '../../core/widgets/vibe_page.dart';
import '../../models/capture_input.dart';
import '../../state/app_state.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({this.initialTab = 'camera', super.key});

  final String initialTab;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _picker = ImagePicker();
  String? _error;
  bool _permissionDenied = false;
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return VibePage(
        bottomNavigationBar: const VibeBottomNav(current: 'capture'),
        child: EmptyState(
          icon: CupertinoIcons.lock_fill,
          title: 'Cần quyền truy cập ảnh',
          message:
              'VibeLens cần quyền camera hoặc thư viện để gửi ảnh đến backend AI.',
          actionLabel: 'Mở Settings',
          onAction: openAppSettings,
        ),
      );
    }

    final actions = widget.initialTab == 'photos'
        ? [
            _CaptureAction.upload(onTap: _pickPhoto),
            _CaptureAction.camera(onTap: _capturePhoto),
          ]
        : [
            _CaptureAction.camera(onTap: _capturePhoto),
            _CaptureAction.upload(onTap: _pickPhoto),
          ];

    return VibePage(
      bottomNavigationBar: const VibeBottomNav(current: 'capture'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          _CaptureHeader(onBack: () => context.go('/home')),
          const SizedBox(height: 22),
          Text(
            'Chọn một khoảnh khắc',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ảnh sẽ được xem trước trước khi bạn đồng ý gửi đến backend AI.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < actions.length; i++) ...[
            _CaptureActionPanel(action: actions[i], busy: _isPicking),
            if (i < actions.length - 1) const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _InlineError(message: _error!),
          ],
          const SizedBox(height: 18),
          const _PrivacyNote(),
        ],
      ),
    );
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return true;
    }
    final status = await permission.request();
    if (status.isPermanentlyDenied || status.isDenied) {
      setState(() => _permissionDenied = true);
      return false;
    }
    return true;
  }

  Future<void> _capturePhoto() async {
    if (_isPicking) return;
    setState(() => _error = null);
    if (!await _requestPermission(Permission.camera)) return;
    await _pick(ImageSource.camera);
  }

  Future<void> _pickPhoto() async {
    if (_isPicking) return;
    setState(() => _error = null);
    if (!await _requestPermission(Permission.photos)) return;
    await _pick(ImageSource.gallery);
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _isPicking = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final capture = CaptureInput(
        id: 'capture_${DateTime.now().microsecondsSinceEpoch}',
        type: CaptureType.image,
        mediaPaths: [file.path],
        createdAt: DateTime.now(),
        label: source == ImageSource.camera ? 'Ảnh vừa chụp' : 'Ảnh đã chọn',
      );
      ref.read(appStateProvider).startCapture(capture, mediaBytes: bytes);
      if (mounted) context.go('/preview');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Không thể lấy ảnh. Hãy kiểm tra quyền truy cập hoặc chọn ảnh khác.';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Quay lại',
          onPressed: onBack,
          icon: const Icon(CupertinoIcons.chevron_left),
        ),
        Expanded(
          child: Text(
            'Capture',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _CaptureActionPanel extends StatelessWidget {
  const _CaptureActionPanel({required this.action, required this.busy});

  final _CaptureAction action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = busy;
    return Semantics(
      button: true,
      enabled: !disabled,
      child: InkWell(
        onTap: disabled ? null : action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.separator),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: action.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: action.accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.tertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.grouped,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.lock_shield_fill, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ảnh gốc không lưu mặc định. Bạn sẽ xác nhận trước khi AI phân tích.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: AppColors.pink,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _CaptureAction {
  const _CaptureAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  factory _CaptureAction.camera({required VoidCallback onTap}) {
    return _CaptureAction(
      icon: CupertinoIcons.camera_fill,
      title: 'Chụp ảnh',
      subtitle: 'Mở camera và tạo ảnh mới cho VibeLens',
      accent: AppColors.primary,
      tint: AppColors.lavender,
      onTap: onTap,
    );
  }

  factory _CaptureAction.upload({required VoidCallback onTap}) {
    return _CaptureAction(
      icon: CupertinoIcons.photo_on_rectangle,
      title: 'Tải ảnh lên',
      subtitle: 'Chọn ảnh có sẵn từ thư viện của bạn',
      accent: AppColors.green,
      tint: AppColors.green.withValues(alpha: 0.12),
      onTap: onTap,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;
}

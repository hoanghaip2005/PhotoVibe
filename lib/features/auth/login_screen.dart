import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/vibe_page.dart';
import '../../state/app_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.nextPath, super.key});

  final String? nextPath;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appStateProvider).userPreferences;
    _emailController = TextEditingController(text: prefs.email);
    _nameController = TextEditingController(
      text: prefs.isSignedIn ? prefs.displayName : '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    return VibePage(
      useGradient: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFBFAF7), Color(0xFFF5F3EF)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          children: [
            _LoginTopBar(onBack: () => _goNext(appState)),
            const SizedBox(height: 44),
            const _LoginHero(),
            const SizedBox(height: 34),
            Form(
              key: _formKey,
              child: _EmailIdentityGroup(
                emailController: _emailController,
                nameController: _nameController,
                emailValidator: _validateEmail,
                onSubmitted: _submit,
              ),
            ),
            const SizedBox(height: 14),
            _PrimaryContinueButton(onPressed: _submit),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _continueLocal,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text('Dùng hồ sơ local'),
            ),
            const SizedBox(height: 12),
            const _PrivacyLine(),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Nhập email để lưu hồ sơ.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    await ref
        .read(appStateProvider)
        .signInWithEmail(
          email: _emailController.text,
          displayName: _nameController.text,
        );
    if (mounted) _goNext(ref.read(appStateProvider));
  }

  Future<void> _continueLocal() async {
    await ref.read(appStateProvider).completeAuthPrompt();
    if (mounted) _goNext(ref.read(appStateProvider));
  }

  void _goNext(VibeAppState appState) {
    if (!appState.musicProfileCompleted) {
      context.go('/music-setup');
    } else if (widget.nextPath == 'profile') {
      context.go('/profile');
    } else if (widget.nextPath == 'notifications') {
      context.go('/notifications');
    } else {
      context.go('/home');
    }
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Quay lại',
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.05),
            foregroundColor: AppColors.ink,
          ),
          icon: const Icon(CupertinoIcons.chevron_left, size: 18),
        ),
        const Spacer(),
        const Text(
          'VibeLens Profile',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.camera_fill,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Tạo hồ sơ VibeLens',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 32,
            height: 1.06,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Giữ diary, gu nhạc và playlist của bạn gọn trong một hồ sơ.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _EmailIdentityGroup extends StatelessWidget {
  const _EmailIdentityGroup({
    required this.emailController,
    required this.nameController,
    required this.emailValidator,
    required this.onSubmitted,
  });

  final TextEditingController emailController;
  final TextEditingController nameController;
  final FormFieldValidator<String> emailValidator;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _IdentityTextField(
            controller: emailController,
            icon: CupertinoIcons.at,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: emailValidator,
          ),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
          _IdentityTextField(
            controller: nameController,
            icon: CupertinoIcons.person_fill,
            label: 'Tên hiển thị',
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmitted(),
          ),
        ],
      ),
    );
  }
}

class _IdentityTextField extends StatelessWidget {
  const _IdentityTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        prefixIcon: Icon(icon, color: AppColors.muted),
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryContinueButton extends StatelessWidget {
  const _PrimaryContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text('Tiếp tục'),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Email chỉ dùng để nhận diện hồ sơ trên thiết bị này. Ảnh chỉ gửi đi khi bạn xác nhận phân tích.',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.muted, height: 1.45),
    );
  }
}

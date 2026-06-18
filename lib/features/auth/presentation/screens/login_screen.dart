import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

/// Phone number entry screen — dark, premium photography studio aesthetic.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedUserType = 'studio_owner';
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    final success = await ref.read(authNotifierProvider.notifier).sendOtp(
          phone: phone,
          userType: _selectedUserType,
        );
    if (!mounted) return;
    if (success) {
      context.push(
        '/otp?phone=${Uri.encodeComponent(phone)}'
        '&userType=${Uri.encodeComponent(_selectedUserType)}',
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── Background gradient blobs ────────────────────────────────────
            Positioned(
              top: -80,
              right: -80,
              child: _GradientBlob(
                color: cs.primary.withValues(alpha: 0.12),
                size: 280,
              ),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: _GradientBlob(
                color: cs.secondary.withValues(alpha: 0.08),
                size: 220,
              ),
            ),

            // ── Main content ─────────────────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 56),

                        // ── Logo / brand mark ───────────────────────────────
                        _BrandMark(color: cs.primary),

                        const SizedBox(height: 40),

                        // ── Headline ────────────────────────────────────────
                        Text(
                          'Welcome back.',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontSize: 36),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to your studio',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 15),
                        ),

                        const SizedBox(height: 44),

                        // ── User type toggle ────────────────────────────────
                        _UserTypeToggle(
                          selected: _selectedUserType,
                          onChanged: isLoading
                              ? null
                              : (v) => setState(() => _selectedUserType = v),
                        ),

                        const SizedBox(height: 28),

                        // ── Phone field ─────────────────────────────────────
                        _PhoneField(
                          controller: _phoneController,
                          enabled: !isLoading,
                        ),

                        const SizedBox(height: 32),

                        // ── Submit button ───────────────────────────────────
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Continue'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Helper text ─────────────────────────────────────
                        Center(
                          child: Text(
                            "We'll send a one-time code to verify your number.\n"
                            'Dev mode: OTP appears in the backend terminal, not SMS.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.camera_alt_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'Studio Gallery',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _UserTypeToggle extends StatelessWidget {
  const _UserTypeToggle({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Studio Owner',
            icon: Icons.camera_alt_rounded,
            isSelected: selected == 'studio_owner',
            onTap: onChanged != null ? () => onChanged!('studio_owner') : null,
            accentColor: cs.primary,
          ),
          _ToggleOption(
            label: 'Customer',
            icon: Icons.person_rounded,
            isSelected: selected == 'customer',
            onTap: onChanged != null ? () => onChanged!('customer') : null,
            accentColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : const Color(0xFF777777),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.black : const Color(0xFF777777),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone number',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF999999),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            color: Color(0xFFF2F2F2),
            fontSize: 16,
            letterSpacing: 0.5,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
          ],
          decoration: const InputDecoration(
            hintText: '+91 98765 43210',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.phone_rounded, size: 20),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          autofillHints: const [AutofillHints.telephoneNumber],
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Phone number is required.';
            if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v)) {
              return 'Enter a valid number with country code (e.g. +919876543210)';
            }
            return null;
          },
        ),
      ],
    );
  }
}

/// Soft radial gradient blob used as background decoration.
class _GradientBlob extends StatelessWidget {
  const _GradientBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}



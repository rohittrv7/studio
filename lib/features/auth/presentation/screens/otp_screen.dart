import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../firebase_options.dart';

import '../providers/auth_provider.dart';

/// OTP entry screen — dark, premium photography studio aesthetic.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.userType = 'customer',
  });

  final String phone;
  final String userType;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  String? _verificationId;
  int? _resendToken;
  bool _isSendingOtp = true;
  String? _sendError;
  bool _firebaseSmsAvailable = false;

  Timer? _lockTimer;
  int _lockSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // SMS OTP via Firebase is not available on web.
    if (kIsWeb) {
      setState(() {
        _isSendingOtp = false;
        _firebaseSmsAvailable = false;
        _sendError =
            'SMS OTP is not available on Web.\nPlease enter the 6-digit OTP code printed in your NestJS backend terminal.';
      });
      return;
    }

    // Check if Firebase is properly configured
    bool isFirebaseConfigured = false;
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      isFirebaseConfigured = !apiKey.startsWith('REPLACE_');
    } catch (_) {}

    if (!isFirebaseConfigured) {
      setState(() {
        _isSendingOtp = false;
        _firebaseSmsAvailable = false;
        _sendError = 'Firebase SMS is not configured.\n'
            'Please enter the 6-digit OTP code printed in your NestJS backend terminal.';
      });
      return;
    }

    _verifyPhoneNumber();

    // Stop blocking the UI if Firebase SMS takes too long.
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted || !_isSendingOtp) return;
      setState(() {
        _isSendingOtp = false;
        _sendError ??=
            'SMS via Firebase is unavailable.\n'
            'Enter the 6-digit code from the backend terminal (dev mode).';
      });
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _lockTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Firebase phone auth ─────────────────────────────────────────────────────

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isSendingOtp = true;
      _sendError = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      forceResendingToken: _resendToken,
      verificationCompleted: _signInWithCredential,
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isSendingOtp = false;
          _sendError = e.message ?? 'Failed to send OTP.';
        });
      },
      codeSent: (id, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _resendToken = token;
          _isSendingOtp = false;
          _sendError = null;
          _firebaseSmsAvailable = true;
        });
      },
      codeAutoRetrievalTimeout: (id) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _isSendingOtp = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _otpController.text.trim();

    // Firebase SMS path when verification ID is available.
    if (_verificationId != null && _firebaseSmsAvailable) {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
      return;
    }

    // Dev OTP path — backend logs OTP to terminal (never in API response).
    final success = await ref.read(authNotifierProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: code,
          userType: widget.userType,
        );
    if (!mounted) return;
    if (!success) {
      // Error shown via ref.listen in build().
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final uc = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await uc.user?.getIdToken();
      if (idToken == null) {
        _showSnackBar('Failed to get auth token. Please try again.');
        return;
      }
      if (!mounted) return;
      final success = await ref.read(authNotifierProvider.notifier).verifyOtp(
            phone: widget.phone,
            idToken: idToken,
            userType: widget.userType,
          );
      // Navigation is handled automatically by GoRouter's refreshListenable
      // watching authNotifierProvider — no explicit context.go() needed.
      if (!mounted) return;
      if (!success) {
        // Error is already shown via the ref.listen in build().
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message ?? 'Invalid OTP, please try again.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred. Please try again.');
    }
  }

  Future<void> _resendOtp() async {
    _otpController.clear();
    await _verifyPhoneNumber();
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() => _lockSecondsRemaining = seconds);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockSecondsRemaining--;
        if (_lockSecondsRemaining <= 0) {
          timer.cancel();
          ref.read(authNotifierProvider.notifier).sendOtp(
                phone: widget.phone,
                userType: widget.userType,
              );
        }
      });
    });
  }

  String _formatDuration(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        if (next.isLocked && next.lockDurationSeconds != null) {
          _startLockCountdown(next.lockDurationSeconds!);
        } else {
          _showSnackBar(next.message);
        }
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isVerifying = authState is AuthLoading;
    final isLocked = _lockSecondsRemaining > 0;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Background blob
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar ───────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFFAAAAAA)),
                        onPressed: () => context.go('/login'),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),

                              // ── Icon ─────────────────────────────────────────
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: cs.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(Icons.sms_rounded,
                                    color: cs.primary, size: 24),
                              ),
                              const SizedBox(height: 24),

                              // ── Headline ─────────────────────────────────────
                              Text(
                                'Enter the code',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'We sent a 6-digit code to\n'),
                                    TextSpan(
                                      text: widget.phone,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // ── Sending indicator ─────────────────────────────
                              if (_isSendingOtp)
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Sending OTP…',
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),

                              // ── Send error / info banner ──────────────────────
                              if (_sendError != null && !_isSendingOtp)
                                _InfoCard(message: _sendError!),

                              // ── Locked banner ─────────────────────────────────
                              if (isLocked)
                                _LockBanner(
                                  seconds: _lockSecondsRemaining,
                                  formatted:
                                      _formatDuration(_lockSecondsRemaining),
                                  accentColor: cs.error,
                                ),

                              // ── OTP input + buttons ───────────────────────────
                              if (!isLocked && !_isSendingOtp) ...[
                                _OtpInputField(
                                  controller: _otpController,
                                  accentColor: cs.primary,
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    onPressed:
                                        isVerifying ? null : _submit,
                                    child: isVerifying
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.black,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('Verify Code'),
                                              SizedBox(width: 8),
                                              Icon(Icons.check_rounded,
                                                  size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: isVerifying ? null : _resendOtp,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Resend code'),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _OtpInputField extends StatelessWidget {
  const _OtpInputField({
    required this.controller,
    required this.accentColor,
  });

  final TextEditingController controller;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofocus: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 16,
        color: accentColor,
      ),
      decoration: const InputDecoration(
        hintText: '• • • • • •',
        hintStyle: TextStyle(
          color: Color(0xFF444444),
          fontSize: 22,
          letterSpacing: 12,
        ),
        counterText: '',
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: (v) {
        if ((v?.trim() ?? '').length != 6) {
          return 'Enter the 6-digit code.';
        }
        return null;
      },
    );
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner({
    required this.seconds,
    required this.formatted,
    required this.accentColor,
  });

  final int seconds;
  final String formatted;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_clock_rounded, color: accentColor, size: 32),
          const SizedBox(height: 10),
          Text(
            'Account temporarily locked',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try again in $formatted',
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    const infoColor = Color(0xFFE8B86D);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: infoColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: infoColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: infoColor, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}



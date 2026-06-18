import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Animated splash screen shown while auth state is determined.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _slideshowCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  // Photoshoot slideshow images
  final List<String> _photos = [
    'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&q=80&w=800',
  ];
  int _photoIndex = 0;
  Timer? _photoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    
    _slideshowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    // Photoshoot slide timer
    _photoTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (mounted) {
        setState(() {
          _photoIndex = (_photoIndex + 1) % _photos.length;
        });
        _slideshowCtrl.forward(from: 0.0);
      }
    });

    // Start first image zoom animation
    _slideshowCtrl.forward(from: 0.0);

    // Dynamic delay: 800ms if already authenticated, 2500ms if not
    final authState = ref.read(authNotifierProvider);
    final isAuthed = authState is AuthAuthenticated;
    final delayMs = isAuthed ? 800 : 2500;

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        ref.read(splashFinishedProvider.notifier).state = true;
      }
    });
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    _ctrl.dispose();
    _slideshowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Stack(
          children: [
            // ── Background Photoshoot Slideshow ─────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _slideshowCtrl,
                builder: (context, child) {
                  final scale = Tween<double>(begin: 1.0, end: 1.15).evaluate(
                    CurvedAnimation(parent: _slideshowCtrl, curve: Curves.easeOutSine),
                  );

                  // Shutter flash effect: quick spike to white then fade out
                  double flashOpacity = 0.0;
                  final t = _slideshowCtrl.value;
                  if (t < 0.10) {
                    flashOpacity = (t / 0.10) * 0.75;
                  } else if (t < 0.40) {
                    flashOpacity = 0.75 * (1.0 - (t - 0.10) / 0.30);
                  }

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Transform.scale(
                          scale: scale,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: Image.network(
                              _photos[_photoIndex],
                              key: ValueKey<int>(_photoIndex),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, _, __) => Container(color: const Color(0xFF0D0D0D)),
                              loadingBuilder: (context, imgChild, progress) {
                                if (progress == null) return imgChild;
                                return Container(color: const Color(0xFF0D0D0D));
                              },
                            ),
                          ),
                        ),
                      ),
                      if (flashOpacity > 0.0)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white.withValues(alpha: flashOpacity),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // Dark elegant glassmorphic overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                ),
              ),
            ),

            // Radial glow behind icon
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x22E8B86D),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: gold,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Studio Gallery',
                        style: TextStyle(
                          color: gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Photography made personal',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: gold.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
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

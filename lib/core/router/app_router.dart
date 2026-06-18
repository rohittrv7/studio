import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/gallery/presentation/screens/folder_view_screen.dart';
import '../../features/gallery/presentation/screens/galleries_screen.dart';
import '../../features/gallery/presentation/screens/gallery_detail_screen.dart';
import '../../features/gallery/presentation/screens/splash_screen.dart';
import '../../features/media/presentation/screens/media_viewer_screen.dart';
import '../../features/qr_scanner/presentation/screens/qr_landing_screen.dart';
import '../../features/qr_scanner/presentation/screens/qr_scanner_screen.dart';

import '../../main.dart' show navigatorKey;

/// Riverpod provider that exposes the configured [GoRouter] instance.
///
/// The router uses [authNotifierProvider] as a [refreshListenable] so that
/// GoRouter re-evaluates the redirect logic whenever auth state changes
/// (e.g. after a successful login or logout).
final splashFinishedProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  // Build a ChangeNotifier that fires whenever auth state changes.
  // GoRouter's refreshListenable uses this to re-run the redirect.
  final authNotifier = _AuthStateNotifier(ref);

  final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,

    // ------------------------------------------------------------------
    // Global redirect logic
    // ------------------------------------------------------------------
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoading = authState is AuthLoading;
      final path = state.matchedLocation;

      // Splash screen '/' — stay here until minimum splash duration has elapsed.
      if (path == '/') {
        final splashFinished = ref.read(splashFinishedProvider);
        if (!splashFinished) return null; // keep showing splash

        if (isLoading) return null; // keep showing splash
        if (isAuthenticated) {
          final user = authState.user;
          if (user.name == 'Studio Owner' || user.name == 'User') {
            return '/onboarding';
          }
          return '/galleries';
        }
        return '/login'; // default — show login
      }

      // Public paths: login + OTP.
      final isPublicPath = path == '/login' || path.startsWith('/otp');

      if (isLoading && !isPublicPath) return null; // wait on current screen

      if (!isAuthenticated && !isPublicPath) {
        return '/login';
      }
      if (isAuthenticated) {
        final user = authState.user;
        final isNewUser = user.name == 'Studio Owner' || user.name == 'User';

        if (isNewUser && path != '/onboarding') {
          return '/onboarding';
        }
        if (!isNewUser && path == '/onboarding') {
          return '/galleries';
        }
        if (path == '/login') {
          return '/galleries';
        }
      }
      return null;
    },

    // ------------------------------------------------------------------
    // Routes
    // ------------------------------------------------------------------
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final userType =
              state.uri.queryParameters['userType'] ?? 'studio_owner';
          return OtpScreen(phone: phone, userType: userType);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/galleries',
        builder: (context, state) => const GalleriesScreen(),
      ),
      GoRoute(
        path: '/galleries/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GalleryDetailScreen(id: id);
        },
        routes: [
          GoRoute(
            path: 'folders/:folderId',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final folderId = state.pathParameters['folderId']!;
              return FolderViewScreen(id: id, folderId: folderId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/galleries/:id/media/:mediaId',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final mediaId = state.pathParameters['mediaId']!;
          return MediaViewerScreen(galleryId: id, mediaId: mediaId);
        },
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/qr',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/gallery/:token',
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return QrLandingScreen(token: token);
        },
      ),
    ],

    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );

  // Dispose the notifier when the provider is disposed.
  ref.onDispose(authNotifier.dispose);

  return router;
});

// ---------------------------------------------------------------------------
// _AuthStateNotifier — bridges Riverpod auth state → GoRouter refreshListenable
// ---------------------------------------------------------------------------

/// A [ChangeNotifier] that listens to [authNotifierProvider] and calls
/// [notifyListeners] whenever the auth state changes.
///
/// GoRouter uses this as its [refreshListenable] to re-run the redirect
/// callback on every auth state transition (login, logout, loading).
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    _authSubscription = ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
    _splashSubscription = ref.listen<bool>(
      splashFinishedProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<bool> _splashSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _splashSubscription.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Error screen
// ---------------------------------------------------------------------------

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFF555555), size: 40),
            const SizedBox(height: 12),
            Text(
              error?.toString() ?? 'Unknown route',
              style: const TextStyle(color: Color(0xFF777777), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

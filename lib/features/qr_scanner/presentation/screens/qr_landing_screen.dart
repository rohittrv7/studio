import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/storage_providers.dart';
import '../../../../core/widgets/error_display.dart';
import '../providers/qr_provider.dart';

/// QR deep-link landing screen.
///
/// Receives a [token] from the router and immediately validates it against
/// the backend.
///
/// - HTTP 200 + authenticated → navigate to the gallery directly.
/// - HTTP 200 + unauthenticated → store pending token and navigate to login.
/// - HTTP 403 / 410 → show "Gallery link is no longer valid" error card.
/// - Network error → show "Unable to connect" error card.
class QrLandingScreen extends ConsumerStatefulWidget {
  const QrLandingScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<QrLandingScreen> createState() => _QrLandingScreenState();
}

class _QrLandingScreenState extends ConsumerState<QrLandingScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off validation after the first frame so the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(qrValidationProvider.notifier).validate(widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to state transitions for navigation side-effects.
    ref.listen(qrValidationProvider, (previous, next) {
      next.whenData((result) {
        if (result == null) return;

        final accessToken = ref.read(hiveStorageProvider).getAccessToken();
        final isAuthenticated = accessToken != null && accessToken.isNotEmpty;

        if (isAuthenticated) {
          // Already logged in — go straight to the target: media file, folder, or gallery.
          if (result.mediaFileId != null) {
            context.go('/galleries/${result.galleryId}/media/${result.mediaFileId}');
          } else if (result.folderId != null) {
            context.go('/galleries/${result.galleryId}/folders/${result.folderId}');
          } else {
            context.go('/galleries/${result.galleryId}');
          }
        } else {
          // Save pending token and send to login.
          ref.read(hiveStorageProvider).savePendingQrToken(widget.token).then((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
        }
      });
    });

    final validationState = ref.watch(qrValidationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opening Gallery'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: validationState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (result) {
            // Navigation handled by the listener above.
            // Show a spinner while the app navigates.
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, _) {
            return ErrorDisplay(
              title: 'This QR is not valid',
              message: 'The link may have expired or is incorrect.',
              onRetry: () => context.go('/galleries'),
              retryLabel: 'Go Back',
            );
          },
        ),
      ),
    );
  }
}

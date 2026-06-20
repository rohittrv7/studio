import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/storage_providers.dart';
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
            return const _ErrorCard(
              message: 'This QR is not valid',
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card widget
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

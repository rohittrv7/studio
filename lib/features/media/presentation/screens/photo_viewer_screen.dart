import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/favorites/presentation/providers/favorites_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gallery/presentation/providers/gallery_provider.dart';
import '../../../qr_scanner/presentation/widgets/qr_display_dialog.dart';
import '../../domain/entities/media_file.dart';
import '../providers/media_provider.dart';
import '../../../../core/utils/security_util.dart';

/// Full-featured photo viewer with swipe navigation, zoom, favorites, and
/// optional download action.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.galleryId,
    required this.mediaIds,
    required this.initialIndex,
  });

  /// The gallery this photo belongs to.
  final String galleryId;

  /// Ordered list of all photo IDs in the current folder/gallery.
  final List<String> mediaIds;

  /// Index of the photo to display first.
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController;

  /// Notifier that tracks the currently visible page index so the AppBar
  /// counter can rebuild cheaply without rebuilding the whole tree.
  late final ValueNotifier<int> _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = ValueNotifier<int>(widget.initialIndex);
    _pageController = PageController(initialPage: widget.initialIndex);
    // Secure by default when entering the photo viewer
    SecurityUtil.setSecure(true);
  }

  @override
  void dispose() {
    // Clear secure flag when leaving the screen
    SecurityUtil.setSecure(false);
    _pageController.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _toggleFavorite(String mediaId) {
    ref.read(favoritesNotifierProvider.notifier).toggle(mediaId);
  }

  void _onDownloadTap() {
    final mediaId = widget.mediaIds[_currentIndex.value];
    ref.read(downloadNotifierProvider.notifier).startDownload(
      galleryId: widget.galleryId,
      mediaId: mediaId,
      fileName: '$mediaId.jpg',
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final total = widget.mediaIds.length;
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudioOwner = user?.isStudioOwner ?? false;

    final galleryAsync = ref.watch(galleryDetailProvider(widget.galleryId));
    final hasFullAccess = galleryAsync.maybeWhen(
      data: (g) => isStudioOwner || (g.customerId == user?.id),
      orElse: () => false,
    );

    // Apply or clear window flags dynamically based on access permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasFullAccess) {
        SecurityUtil.setSecure(false);
      } else {
        SecurityUtil.setSecure(true);
      }
    });

    // Listen for download completion / errors and show SnackBars.
    ref.listen<Map<String, DownloadState>>(
      downloadNotifierProvider,
      (previous, next) {
        final mediaId = widget.mediaIds[_currentIndex.value];
        final prev = previous?[mediaId];
        final curr = next[mediaId];
        if (curr == null) return;
        if (curr.completed && !(prev?.completed ?? false)) {
          final savedMsg = curr.savePath != null
              ? 'Saved to: ${curr.savePath}'
              : 'Download complete';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Download complete!\n$savedMsg',
                style: const TextStyle(fontSize: 13),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (curr.error != null && prev?.error == null) {
          final capturedMediaId =
              widget.mediaIds[_currentIndex.value];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${curr.error}'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  ref
                      .read(downloadNotifierProvider.notifier)
                      .startDownload(
                        galleryId: widget.galleryId,
                        mediaId: capturedMediaId,
                        fileName: '$capturedMediaId.jpg',
                      );
                },
              ),
            ),
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/galleries/${widget.galleryId}');
            }
          },
        ),
        // Counter text updates on swipe without rebuilding the whole scaffold.
        title: ValueListenableBuilder<int>(
          valueListenable: _currentIndex,
          builder: (context, index, _) {
            return Text(
              '${index + 1} / $total',
              style: const TextStyle(color: Colors.white),
            );
          },
        ),
        actions: [
          if (isStudioOwner)
            ValueListenableBuilder<int>(
              valueListenable: _currentIndex,
              builder: (context, index, _) {
                final mediaId = widget.mediaIds[index];
                return IconButton(
                  icon: const Icon(Icons.qr_code_rounded, color: Color(0xFFE8B86D)),
                  tooltip: 'Get Photo QR Code',
                  onPressed: () {
                    QrDisplayDialog.show(
                      context,
                      galleryId: widget.galleryId,
                      mediaFileId: mediaId,
                      title: 'Photo QR Code',
                    );
                  },
                );
              },
            ),
          // Download button — shown only when the current media permits it.
          ValueListenableBuilder<int>(
            valueListenable: _currentIndex,
            builder: (context, index, _) {
              if (!hasFullAccess) return const SizedBox.shrink();
              final mediaId = widget.mediaIds[index];
              final mediaAsync = ref.watch(
                mediaFileProvider((widget.galleryId, mediaId)),
              );
              final permitted = mediaAsync.whenOrNull(
                    data: (file) => file.downloadPermitted,
                  ) ??
                  false;

              if (!permitted) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download',
                onPressed: _onDownloadTap,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Download progress bar — shown at top of body while downloading.
          ValueListenableBuilder<int>(
            valueListenable: _currentIndex,
            builder: (context, index, _) {
              final mediaId = widget.mediaIds[index];
              final downloadStates = ref.watch(downloadNotifierProvider);
              final downloadState = downloadStates[mediaId];
              if (downloadState?.isDownloading == true) {
                return LinearProgressIndicator(
                  value: downloadState!.progress > 0
                      ? downloadState.progress
                      : null, // indeterminate when progress == 0
                  backgroundColor: Colors.grey[800],
                  color: Colors.white,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (index) => _currentIndex.value = index,
              itemBuilder: (context, index) {
                final mediaId = widget.mediaIds[index];
                return _PhotoPage(
                  galleryId: widget.galleryId,
                  mediaId: mediaId,
                  onFavoriteTap: _toggleFavorite,
                  hasFullAccess: hasFullAccess,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-page widget
// ---------------------------------------------------------------------------

/// A single photo page inside the [PageView].
///
/// Loads the [MediaFile] via [mediaFileProvider] and renders it with
/// [InteractiveViewer] for pinch-to-zoom.  Shows a favorites toggle overlay.
class _PhotoPage extends ConsumerWidget {
  const _PhotoPage({
    required this.galleryId,
    required this.mediaId,
    required this.onFavoriteTap,
    required this.hasFullAccess,
  });

  final String galleryId;
  final String mediaId;
  final void Function(String mediaId) onFavoriteTap;
  final bool hasFullAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaFileProvider((galleryId, mediaId)));
    final isFavorite = ref.watch(isFavoriteProvider(mediaId));

    return mediaAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            const SizedBox(height: 12),
            Text(
              'Failed to load image',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
      data: (mediaFile) => _PhotoPageContent(
        mediaFile: mediaFile,
        isFavorite: isFavorite,
        onFavoriteTap: () => onFavoriteTap(mediaId),
        hasFullAccess: hasFullAccess,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded photo content
// ---------------------------------------------------------------------------

class _PhotoPageContent extends StatelessWidget {
  const _PhotoPageContent({
    required this.mediaFile,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.hasFullAccess,
  });

  final MediaFile mediaFile;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final bool hasFullAccess;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ------------------------------------------------------------------
        // Zoomable full-res image
        // ------------------------------------------------------------------
        Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: mediaFile.secureUrl,
              // While the full-res image loads, show the already-cached
              // thumbnail so there is no blank flash.
              placeholder: (context, url) => CachedNetworkImage(
                imageUrl: mediaFile.thumbnailUrl,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
              fit: BoxFit.contain,
            ),
          ),
        ),

        // ------------------------------------------------------------------
        // Favorite heart overlay — bottom-right corner
        // ------------------------------------------------------------------
        if (hasFullAccess)
          Positioned(
            right: 16,
            bottom: 24,
            child: GestureDetector(
              onTap: onFavoriteTap,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.white,
                size: 32,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

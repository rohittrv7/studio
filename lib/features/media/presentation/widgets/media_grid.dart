import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/favorites/presentation/providers/favorites_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gallery/presentation/providers/gallery_provider.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/usecases/get_media_usecase.dart';
import '../providers/media_provider.dart';
import '../screens/photo_viewer_screen.dart';
import '../screens/video_player_screen.dart';

/// A paginated grid of media thumbnails for a gallery / folder.
///
/// Supports infinite scroll, tap-to-view (photo or video), favorite overlays,
/// and video-play indicators.
class MediaGrid extends ConsumerStatefulWidget {
  const MediaGrid({
    super.key,
    required this.galleryId,
    this.folderId,
    this.prependSlivers,
    this.emptyPlaceholder,
  });

  final String galleryId;
  final String? folderId;
  final List<Widget>? prependSlivers;
  final Widget? emptyPlaceholder;

  @override
  ConsumerState<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends ConsumerState<MediaGrid> {
  final List<MediaFile> _allMedia = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final useCase = ref.read(getMediaUseCaseProvider);
      final newMedia = await useCase(GetMediaParams(
        galleryId: widget.galleryId,
        page: _currentPage,
        folderId: widget.folderId,
      ));
      setState(() {
        _allMedia.addAll(newMedia);
        _currentPage++;
        // Default page size is 30; fewer results means no more pages.
        if (newMedia.length < 30) _hasMore = false;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      debugPrint('Error loading media: $e\n$st');
      setState(() => _isLoadingMore = false);
    }
  }

  void _onTapMedia(MediaFile item) {
    if (item.mediaType == MediaType.photo) {
      final photoIds = _allMedia
          .where((m) => m.mediaType == MediaType.photo)
          .map((m) => m.id)
          .toList();
      final photoIndex = photoIds.indexOf(item.id);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(
            galleryId: widget.galleryId,
            mediaIds: photoIds,
            initialIndex: photoIndex,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(mediaFile: item),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPrepend = widget.prependSlivers != null && widget.prependSlivers!.isNotEmpty;

    // Empty state — only shown once the first load has finished and found nothing.
    if (_allMedia.isEmpty && !_isLoadingMore && !hasPrepend) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: widget.emptyPlaceholder ??
                const Center(
                  child: Text(
                    'No media in this folder',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
          ),
        ],
      );
    }

    // Watch gallery and auth details once at parent level for high performance
    final galleryAsync = ref.watch(galleryDetailProvider(widget.galleryId));
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isStudioOwner = user?.isStudioOwner ?? false;
    final hasFullAccess = galleryAsync.maybeWhen(
      data: (gallery) => isStudioOwner || (gallery.customerId == user?.id),
      orElse: () => false,
    );

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (widget.prependSlivers != null) ...widget.prependSlivers!,

        if (hasPrepend && _allMedia.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Photos & Videos',
                style: TextStyle(
                  color: Color(0xFFF2F2F2),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),

        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _allMedia[index];
              return GestureDetector(
                onTap: () => _onTapMedia(item),
                child: _MediaCell(
                  item: item,
                  hasFullAccess: hasFullAccess,
                ),
              );
            },
            childCount: _allMedia.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
        ),

        // Loading footer
        SliverToBoxAdapter(
          child: _isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual grid cell
// ---------------------------------------------------------------------------

class _MediaCell extends ConsumerWidget {
  const _MediaCell({
    required this.item,
    required this.hasFullAccess,
  });

  final MediaFile item;
  final bool hasFullAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(item.id));

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        CachedNetworkImage(
          imageUrl: item.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(color: Colors.grey[200]),
          errorWidget: (context, url, error) =>
              Container(color: Colors.grey[300]),
        ),

        // Video play indicator
        if (item.mediaType == MediaType.video)
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 32,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),

        // Favorite heart indicator
        if (isFavorite && hasFullAccess)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.favorite,
              color: Colors.red,
              size: 16,
            ),
          ),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/media/domain/entities/media_file.dart';
import '../../../../features/media/presentation/screens/photo_viewer_screen.dart';
import '../../../../features/media/presentation/screens/video_player_screen.dart';
import '../../domain/entities/favorite.dart';
import '../providers/favorites_provider.dart';

/// Screen that displays all favorited media items sorted by [Favorite.createdAt]
/// DESC, with infinite scroll pagination (page size = 30).
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  static const int _pageSize = 30;

  final List<Favorite> _allFavorites = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _initialError;
  bool _initialLoading = true;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadPage(1);
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
      _loadPage(_currentPage);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final useCase = ref.read(listFavoritesUseCaseProvider);
      final newItems = await useCase(page: page, limit: _pageSize);

      // Sort each incoming page by createdAt DESC (server already returns DESC,
      // but defensive sort ensures correctness).
      newItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allFavorites.addAll(newItems);
        _currentPage = page + 1;
        if (newItems.length < _pageSize) _hasMore = false;
        _isLoadingMore = false;
        _initialLoading = false;
        _initialError = null;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _initialLoading = false;
        if (_allFavorites.isEmpty) _initialError = e;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _allFavorites.clear();
      _currentPage = 1;
      _hasMore = true;
      _initialError = null;
      _initialLoading = true;
    });
    // Also invalidate the notifier so isFavoriteProvider reflects server state.
    ref.invalidate(favoritesNotifierProvider);
    await _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Initial loading spinner (first page not yet fetched).
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Initial load failed and list is empty.
    if (_initialError != null && _allFavorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Failed to load favourites',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _initialError.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state — no favorites at all.
    if (_allFavorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No favourites yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on any photo to add it here.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _refresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Populated list with infinite scroll.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        // +1 for the loading footer slot.
        itemCount: _allFavorites.length + (_isLoadingMore || _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _allFavorites.length) {
            // Footer: spinner while loading more, invisible sentinel otherwise.
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          return _FavoriteListItem(favorite: _allFavorites[index]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List item widget
// ---------------------------------------------------------------------------

class _FavoriteListItem extends ConsumerWidget {
  const _FavoriteListItem({required this.favorite});

  final Favorite favorite;

  void _onTap(BuildContext context, MediaFile? mediaFile) {
    if (mediaFile == null) return;
    if (mediaFile.mediaType == MediaType.photo) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(
            galleryId: mediaFile.galleryId,
            mediaIds: [mediaFile.id],
            initialIndex: 0,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(mediaFile: mediaFile),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaFile = favorite.mediaFile;

    // Reactive heart state — reflects live FavoritesNotifier state.
    final isFavorite = ref.watch(isFavoriteProvider(favorite.mediaFileId));

    return ListTile(
      onTap: mediaFile != null ? () => _onTap(context, mediaFile) : null,
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: mediaFile != null
              ? CachedNetworkImage(
                  imageUrl: mediaFile.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey[300]),
                )
              : Container(color: Colors.grey[300]),
        ),
      ),
      title: Text(
        mediaFile != null
            ? (mediaFile.mediaType.name[0].toUpperCase() +
                mediaFile.mediaType.name.substring(1))
            : 'Media',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        mediaFile != null
            ? 'Gallery: ${mediaFile.galleryId}'
            : 'ID: ${favorite.mediaFileId}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : Colors.grey,
        ),
        tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
        onPressed: () {
          ref
              .read(favoritesNotifierProvider.notifier)
              .toggle(favorite.mediaFileId);
        },
      ),
    );
  }
}

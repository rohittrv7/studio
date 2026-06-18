import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../../data/datasources/favorites_remote_data_source.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/usecases/add_favorite_usecase.dart';
import '../../domain/usecases/list_favorites_usecase.dart';
import '../../domain/usecases/remove_favorite_usecase.dart';

// ---------------------------------------------------------------------------
// Dependency providers
// ---------------------------------------------------------------------------

/// Provides the [FavoritesRemoteDataSource] implementation.
final favoritesRemoteDataSourceProvider =
    Provider<FavoritesRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return FavoritesRemoteDataSourceImpl(dio);
});

/// Provides the [FavoritesRepository] implementation.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepositoryImpl(
    remote: ref.watch(favoritesRemoteDataSourceProvider),
  );
});

/// Provides the [AddFavoriteUseCase].
final addFavoriteUseCaseProvider = Provider<AddFavoriteUseCase>((ref) {
  return AddFavoriteUseCase(ref.watch(favoritesRepositoryProvider));
});

/// Provides the [RemoveFavoriteUseCase].
final removeFavoriteUseCaseProvider = Provider<RemoveFavoriteUseCase>((ref) {
  return RemoveFavoriteUseCase(ref.watch(favoritesRepositoryProvider));
});

/// Provides the [ListFavoritesUseCase].
final listFavoritesUseCaseProvider = Provider<ListFavoritesUseCase>((ref) {
  return ListFavoritesUseCase(ref.watch(favoritesRepositoryProvider));
});

// ---------------------------------------------------------------------------
// FavoritesNotifier
// ---------------------------------------------------------------------------

/// Manages the favorites list with optimistic UI updates.
class FavoritesNotifier extends AsyncNotifier<List<Favorite>> {
  @override
  Future<List<Favorite>> build() async {
    final useCase = ref.watch(listFavoritesUseCaseProvider);
    // Initial load: fetch first page with a large enough limit so the
    // common case (few favorites) loads in one shot. The FavoritesScreen
    // handles incremental pagination on its own.
    return useCase(page: 1, limit: 30);
  }

  /// Toggles the favorite state of [mediaFileId].
  ///
  /// Uses optimistic updates: the local state is mutated immediately before
  /// the network call.  On error, the previous state is restored.
  Future<void> toggle(String mediaFileId) async {
    final previous = state;
    final currentList = state.valueOrNull ?? [];
    final alreadyFavorited =
        currentList.any((f) => f.mediaFileId == mediaFileId);

    if (alreadyFavorited) {
      // Optimistically remove from local state.
      final optimistic =
          currentList.where((f) => f.mediaFileId != mediaFileId).toList();
      state = AsyncData(optimistic);

      try {
        await ref.read(removeFavoriteUseCaseProvider)(mediaFileId);
      } catch (_) {
        // Restore previous state on failure.
        state = previous;
        rethrow;
      }
    } else {
      // Optimistically add a placeholder entry.
      final placeholder = Favorite(
        id: 'pending',
        mediaFileId: mediaFileId,
        createdAt: DateTime.now(),
      );
      final optimistic = [placeholder, ...currentList];
      state = AsyncData(optimistic);

      try {
        await ref.read(addFavoriteUseCaseProvider)(mediaFileId);
        // Refresh from server to get the real id and createdAt.
        final updated =
            await ref.read(listFavoritesUseCaseProvider)(page: 1, limit: 30);
        state = AsyncData(updated);
      } catch (_) {
        // Restore previous state on failure.
        state = previous;
        rethrow;
      }
    }
  }

  /// Returns whether [mediaFileId] is currently in the favorites list.
  bool isFavorite(String mediaFileId) {
    return state.valueOrNull
            ?.any((f) => f.mediaFileId == mediaFileId) ??
        false;
  }
}

/// Provider that exposes [FavoritesNotifier] to the widget tree.
final favoritesNotifierProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<Favorite>>(
  FavoritesNotifier.new,
);

/// Family provider that returns whether a specific media file is favorited.
final isFavoriteProvider = Provider.family<bool, String>((ref, mediaFileId) {
  final favorites = ref.watch(favoritesNotifierProvider);
  return favorites.valueOrNull
          ?.any((f) => f.mediaFileId == mediaFileId) ??
      false;
});

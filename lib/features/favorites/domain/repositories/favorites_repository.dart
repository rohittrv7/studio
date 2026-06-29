import '../entities/favorite.dart';

/// Abstract interface for the favorites repository.
abstract class FavoritesRepository {
  /// Returns favorited media items sorted by [Favorite.createdAt] DESC.
  ///
  /// [page] is 1-based. [limit] controls page size (default 30).
  Future<List<Favorite>> listFavorites({int page = 1, int limit = 30});

  /// Marks [mediaFileId] as a favorite.
  Future<void> addFavorite(String mediaFileId);

  /// Removes [mediaFileId] from favorites.
  Future<void> removeFavorite(String mediaFileId);
}

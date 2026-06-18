import '../entities/favorite.dart';
import '../repositories/favorites_repository.dart';

/// Use case: fetch the current user's favorited media items.
class ListFavoritesUseCase {
  const ListFavoritesUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<List<Favorite>> call({int page = 1, int limit = 30}) =>
      _repository.listFavorites(page: page, limit: limit);
}

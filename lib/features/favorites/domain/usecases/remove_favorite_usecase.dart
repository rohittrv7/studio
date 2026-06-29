import '../repositories/favorites_repository.dart';

/// Use case: remove a media file from favorites.
class RemoveFavoriteUseCase {
  const RemoveFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<void> call(String mediaFileId) =>
      _repository.removeFavorite(mediaFileId);
}

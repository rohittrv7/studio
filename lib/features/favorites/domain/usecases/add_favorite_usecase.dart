import '../repositories/favorites_repository.dart';

/// Use case: mark a media file as a favorite.
class AddFavoriteUseCase {
  const AddFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<void> call(String mediaFileId) => _repository.addFavorite(mediaFileId);
}

import '../entities/gallery.dart';
import '../repositories/gallery_repository.dart';

/// Use case that retrieves a single gallery by id.
class GetGalleryUseCase {
  const GetGalleryUseCase(this._repository);

  final GalleryRepository _repository;

  Future<Gallery> call(String id) {
    return _repository.getGallery(id);
  }
}

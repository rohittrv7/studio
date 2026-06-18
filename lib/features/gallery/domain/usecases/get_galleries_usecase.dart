import '../entities/gallery.dart';
import '../repositories/gallery_repository.dart';

/// Use case that retrieves a paginated list of galleries.
class GetGalleriesUseCase {
  const GetGalleriesUseCase(this._repository);

  final GalleryRepository _repository;

  Future<List<Gallery>> call({int page = 1, int limit = 20}) {
    return _repository.getGalleries(page: page, limit: limit);
  }
}

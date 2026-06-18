import '../entities/folder.dart';
import '../repositories/gallery_repository.dart';

/// Use case that retrieves the folder tree for a given gallery.
class GetFolderTreeUseCase {
  const GetFolderTreeUseCase(this._repository);

  final GalleryRepository _repository;

  Future<List<Folder>> call(String galleryId) {
    return _repository.getFolderTree(galleryId);
  }
}

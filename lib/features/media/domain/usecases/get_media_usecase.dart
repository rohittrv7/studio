import '../entities/media_file.dart';
import '../repositories/media_repository.dart';

/// Parameters for [GetMediaUseCase].
class GetMediaParams {
  const GetMediaParams({
    required this.galleryId,
    this.page = 1,
    this.limit = 30,
    this.folderId,
  });

  final String galleryId;
  final int page;
  final int limit;
  final String? folderId;
}

/// Use case that retrieves a paginated list of media files for a gallery.
class GetMediaUseCase {
  const GetMediaUseCase(this._repository);

  final MediaRepository _repository;

  Future<List<MediaFile>> call(GetMediaParams params) =>
      _repository.getMedia(
        params.galleryId,
        page: params.page,
        limit: params.limit,
        folderId: params.folderId,
      );
}

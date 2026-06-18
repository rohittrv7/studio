import '../repositories/media_repository.dart';

/// Use case that downloads a media file to the device.
///
/// Returns the local file path where the file was saved.
class DownloadMediaUseCase {
  const DownloadMediaUseCase(this._repository);

  final MediaRepository _repository;

  Future<String> call({
    required String galleryId,
    required String mediaId,
    required String savePath,
    void Function(int received, int total)? onReceiveProgress,
  }) =>
      _repository.downloadMedia(
        galleryId,
        mediaId,
        savePath,
        onReceiveProgress: onReceiveProgress,
      );
}

import '../entities/media_file.dart';

/// Abstract interface for the media repository.
abstract class MediaRepository {
  /// Fetches a paginated list of media files for a gallery.
  ///
  /// Optionally filtered by [folderId].
  Future<List<MediaFile>> getMedia(
    String galleryId, {
    int page = 1,
    int limit = 30,
    String? folderId,
  });

  /// Fetches a single media file by its [mediaId] within a gallery.
  Future<MediaFile> getMediaFile(String galleryId, String mediaId);

  /// Downloads a media file to [savePath] and returns the path on success.
  ///
  /// Optionally reports download progress via [onReceiveProgress].
  Future<String> downloadMedia(
    String galleryId,
    String mediaId,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  });
}

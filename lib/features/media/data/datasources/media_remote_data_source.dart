import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/media_file_model.dart';

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

/// Remote data source for the media feature.
abstract class MediaRemoteDataSource {
  /// GET `/galleries/:galleryId/media?page=X&limit=Y[&folderId=Z]`
  Future<List<MediaFileModel>> getMedia(
    String galleryId, {
    int page = 1,
    int limit = 30,
    String? folderId,
  });

  /// GET `/galleries/:galleryId/media/:mediaId`
  Future<MediaFileModel> getMediaFile(String galleryId, String mediaId);

  /// Downloads the media file to [savePath].
  ///
  /// Optionally reports download progress via [onReceiveProgress].
  Future<void> downloadMedia(
    String galleryId,
    String mediaId,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// Dio-backed implementation of [MediaRemoteDataSource].
class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  const MediaRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<MediaFileModel>> getMedia(
    String galleryId, {
    int page = 1,
    int limit = 30,
    String? folderId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.galleryMedia(galleryId),
      queryParameters: {
        'page': page,
        'limit': limit,
        if (folderId != null) 'folderId': folderId,
      },
    );
    final rawList = response.data?['data'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(MediaFileModel.fromJson)
        .toList();
  }

  @override
  Future<MediaFileModel> getMediaFile(
    String galleryId,
    String mediaId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.galleryMediaFile(galleryId, mediaId),
    );
    return MediaFileModel.fromJson(response.data!);
  }

  @override
  Future<void> downloadMedia(
    String galleryId,
    String mediaId,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    await _dio.download(
      ApiConstants.galleryMediaFile(galleryId, mediaId),
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

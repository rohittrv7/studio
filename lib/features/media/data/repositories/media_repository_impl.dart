import 'package:dio/dio.dart';

import '../../domain/entities/media_file.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_remote_data_source.dart';

/// Concrete implementation of [MediaRepository].
///
/// All network calls are delegated to [MediaRemoteDataSource]. [DioException]s
/// are mapped to plain [Exception]s so the presentation layer stays free of
/// HTTP concerns.
class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl({required MediaRemoteDataSource remote})
      : _remote = remote;

  final MediaRemoteDataSource _remote;

  // In-memory cache for offline viewing support
  static final Map<String, MediaFile> _mediaCache = {};

  // ---------------------------------------------------------------------------
  // getMedia
  // ---------------------------------------------------------------------------

  @override
  Future<List<MediaFile>> getMedia(
    String galleryId, {
    int page = 1,
    int limit = 30,
    String? folderId,
  }) async {
    try {
      final models = await _remote.getMedia(
        galleryId,
        page: page,
        limit: limit,
        folderId: folderId,
      );
      final entities = models.map((m) => m.toEntity()).toList();
      for (final entity in entities) {
        _mediaCache['$galleryId-${entity.id}'] = entity;
      }
      return entities;
    } on DioException catch (e) {
      final galleryPrefix = '$galleryId-';
      final cachedList = _mediaCache.entries
          .where((entry) => entry.key.startsWith(galleryPrefix))
          .map((entry) => entry.value)
          .toList();
      if (cachedList.isNotEmpty) {
        return cachedList;
      }
      throw _mapException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // getMediaFile
  // ---------------------------------------------------------------------------

  @override
  Future<MediaFile> getMediaFile(String galleryId, String mediaId) async {
    final cacheKey = '$galleryId-$mediaId';
    try {
      final model = await _remote.getMediaFile(galleryId, mediaId);
      final entity = model.toEntity();
      _mediaCache[cacheKey] = entity;
      return entity;
    } on DioException catch (e) {
      if (_mediaCache.containsKey(cacheKey)) {
        return _mediaCache[cacheKey]!;
      }
      throw _mapException(e);
    } catch (e) {
      if (_mediaCache.containsKey(cacheKey)) {
        return _mediaCache[cacheKey]!;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // downloadMedia
  // ---------------------------------------------------------------------------

  @override
  Future<String> downloadMedia(
    String galleryId,
    String mediaId,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      await _remote.downloadMedia(
        galleryId,
        mediaId,
        savePath,
        onReceiveProgress: onReceiveProgress,
      );
      return savePath;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  Exception _mapException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('No internet connection. Please check your network.');
    }
    final statusCode = e.response?.statusCode ?? 0;
    switch (statusCode) {
      case 401:
        return Exception('Authentication required.');
      case 403:
        return Exception('Access denied.');
      case 404:
        return Exception('Media not found.');
      default:
        return Exception('Failed to load media: ${e.message}');
    }
  }
}

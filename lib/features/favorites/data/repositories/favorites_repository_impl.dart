import 'package:dio/dio.dart';

import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_remote_data_source.dart';

/// Concrete implementation of [FavoritesRepository].
///
/// All network calls are delegated to [FavoritesRemoteDataSource]. [DioException]s
/// are mapped to plain [Exception]s so the presentation layer stays free of
/// HTTP concerns.
class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl({required FavoritesRemoteDataSource remote})
      : _remote = remote;

  final FavoritesRemoteDataSource _remote;

  @override
  Future<List<Favorite>> listFavorites({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final models = await _remote.listFavorites(page: page, limit: limit);
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> addFavorite(String mediaFileId) async {
    try {
      await _remote.addFavorite(mediaFileId);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> removeFavorite(String mediaFileId) async {
    try {
      await _remote.removeFavorite(mediaFileId);
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
        return Exception('Favorite not found.');
      case 409:
        return Exception('Already marked as favorite.');
      default:
        return Exception('Failed to update favorites: ${e.message}');
    }
  }
}

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/favorite_model.dart';

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

/// Remote data source for the favorites feature.
abstract class FavoritesRemoteDataSource {
  /// POST `/favorites` with body `{ "mediaFileId": mediaFileId }`.
  Future<void> addFavorite(String mediaFileId);

  /// DELETE `/favorites/:mediaFileId`.
  Future<void> removeFavorite(String mediaFileId);

  /// GET `/favorites?page=X&limit=Y` → list of [FavoriteModel] sorted by
  /// createdAt DESC.
  Future<List<FavoriteModel>> listFavorites({int page = 1, int limit = 30});
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// Dio-backed implementation of [FavoritesRemoteDataSource].
class FavoritesRemoteDataSourceImpl implements FavoritesRemoteDataSource {
  const FavoritesRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> addFavorite(String mediaFileId) async {
    await _dio.post<void>(
      ApiConstants.favorites,
      data: {'mediaFileId': mediaFileId},
    );
  }

  @override
  Future<void> removeFavorite(String mediaFileId) async {
    await _dio.delete<void>(ApiConstants.favoriteDelete(mediaFileId));
  }

  @override
  Future<List<FavoriteModel>> listFavorites({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.favorites,
      queryParameters: {'page': page, 'limit': limit},
    );
    final rawList = response.data?['data'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(FavoriteModel.fromJson)
        .toList();
  }
}

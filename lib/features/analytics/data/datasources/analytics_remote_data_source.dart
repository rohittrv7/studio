import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_providers.dart';

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

/// Remote data source for the analytics feature.
abstract class AnalyticsRemoteDataSource {
  /// Records a gallery view event.
  ///
  /// This is a fire-and-forget call: the method returns immediately without
  /// waiting for the server to respond, so the UI is never blocked.
  /// Any errors are swallowed silently (logged in debug mode only).
  void recordView(String galleryId);
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// Dio-backed implementation of [AnalyticsRemoteDataSource].
///
/// [recordView] posts `{ "galleryId": galleryId }` to `POST /analytics/view`
/// asynchronously using [unawaited] so that the caller is never blocked.
/// Network or server errors are caught and silently discarded; in debug mode
/// the error is printed to the console.
class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  const AnalyticsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  void recordView(String galleryId) {
    // Fire-and-forget: unawaited ensures the Future is not awaited by callers.
    unawaited(
      _dio
          .post<void>(
            ApiConstants.analyticsView,
            data: {'galleryId': galleryId},
          )
          .then((_) {
            // Success — nothing to do.
          })
          .catchError((Object error) {
            // Swallow errors silently; log in debug builds only.
            if (kDebugMode) {
              debugPrint('[Analytics] recordView error for $galleryId: $error');
            }
          }),
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides the [AnalyticsRemoteDataSource] implementation.
final analyticsRemoteDataSourceProvider =
    Provider<AnalyticsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AnalyticsRemoteDataSourceImpl(dio);
});

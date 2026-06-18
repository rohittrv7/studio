import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../errors/failures.dart';
import '../storage/hive_storage.dart';

/// Creates and configures a [Dio] instance with all interceptors attached.
///
/// Interceptor order:
///   1. [AuthInterceptor]   — injects Bearer token; handles 401 refresh/retry
///   2. [LoggingInterceptor] — debug builds only; logs method, path, status
///   3. [ErrorInterceptor]  — maps [DioException] to typed [Failure] objects
Dio createDioClient(HiveStorage storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Required for ngrok and localtunnel free tiers — avoids HTML interstitial on API calls.
        if (ApiConstants.baseUrl.contains('ngrok'))
          'ngrok-skip-browser-warning': 'true',
        if (ApiConstants.baseUrl.contains('loca.lt'))
          'bypass-tunnel-reminder': 'true',
      },
    ),
  );

  // Order matters: Auth → Logging → Error
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) {
    dio.interceptors.add(LoggingInterceptor());
  }
  dio.interceptors.add(ErrorInterceptor());

  return dio;
}

// ---------------------------------------------------------------------------
// AuthInterceptor
// ---------------------------------------------------------------------------

/// Injects the Bearer token on every request.
///
/// On a 401 response, the interceptor:
///   1. Calls `POST /auth/refresh` with the stored refresh token.
///   2. If refresh succeeds, retries the original request once with the new
///      access token (marks the retry via `extra['_retry'] = true`).
///   3. If the retry also returns 401 (or the refresh call itself fails),
///      clears all stored tokens so the app treats the user as logged out.
///
/// A separate bare [Dio] instance (no interceptors) is used for the refresh
/// call and the retry to prevent infinite intercept loops.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final HiveStorage _storage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 once — if the request is already a retry, bail out.
    final isRetry = err.requestOptions.extra['_retry'] == true;
    if (err.response?.statusCode == 401 && !isRetry) {
      try {
        final newAccessToken = await _refreshTokens();
        if (newAccessToken != null) {
          // Retry original request with the fresh access token.
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';
          options.extra['_retry'] = true;

          // Use a plain Dio instance (no interceptors) to avoid infinite loop.
          final retryDio = Dio(
            BaseOptions(
              baseUrl: options.baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

          final response = await retryDio.fetch(options);
          return handler.resolve(response);
        }
      } catch (_) {
        // Refresh or retry failed — fall through to token clear + propagate.
      }

      // Refresh failed (or second 401 received) → clear tokens so that
      // GoRouter's redirect guard sends the user to the login screen.
      await _storage.clearTokens();
    }
    handler.next(err);
  }

  /// Calls the refresh endpoint and persists the new token pair.
  ///
  /// Returns the new access token on success, `null` on any failure.
  Future<String?> _refreshTokens() async {
    final refreshToken = _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    // Use a separate Dio instance to avoid triggering this interceptor again.
    final authDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    final response = await authDio.post<Map<String, dynamic>>(
      ApiConstants.refreshToken,
      data: {'refreshToken': refreshToken},
    );

    final data = response.data;
    if (data == null) return null;

    final newAccess = data['accessToken'] as String?;
    final newRefresh = data['refreshToken'] as String?;

    if (newAccess != null && newRefresh != null) {
      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return newAccess;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// LoggingInterceptor
// ---------------------------------------------------------------------------

/// Logs HTTP traffic in debug builds only.
///
/// Logs: request method + path, response status + path, error status + path.
/// Does NOT log Authorization headers, request bodies, or any PII.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[HTTP] --> ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      '[HTTP] <-- ${response.statusCode} ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[HTTP] ERROR ${err.response?.statusCode ?? "???"} '
      '${err.requestOptions.path}: ${err.type}',
    );
    handler.next(err);
  }
}

// ---------------------------------------------------------------------------
// AppException — wraps a typed Failure so call sites never see DioException
// ---------------------------------------------------------------------------

/// Exception thrown by [ErrorInterceptor] to surface a typed [Failure].
///
/// Repositories and data sources should catch [AppException] instead of
/// [DioException] to keep the presentation layer free of HTTP concerns.
///
/// ```dart
/// try {
///   final resp = await dio.get('/galleries');
/// } on AppException catch (e) {
///   // e.failure is a typed Failure subtype
/// }
/// ```
class AppException implements Exception {
  const AppException(this.failure);

  /// The typed domain failure describing what went wrong.
  final Failure failure;

  @override
  String toString() => 'AppException(${failure.runtimeType})';
}

// ---------------------------------------------------------------------------
// ErrorInterceptor
// ---------------------------------------------------------------------------

/// Maps [DioException] to typed [Failure] domain objects and rethrows them
/// as [AppException] so that calling code never needs to handle raw
/// [DioException]s.
///
/// Status code mapping:
///   400  → [BadRequestFailure]
///   401  → [UnauthorizedFailure]
///   403  → [ForbiddenFailure]
///   404  → [NotFoundFailure]
///   409  → [ConflictFailure]
///   413  → [PayloadTooLargeFailure]
///   415  → [UnsupportedMediaTypeFailure]
///   422  → [UnprocessableEntityFailure]
///   429  → [RateLimitedFailure]
///   5xx  → [ServerFailure]
///   timeout / connection error → [NetworkFailure]
///   otherwise → [UnknownFailure]
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = _mapToFailure(err);

    // Reject with a DioException whose error is our AppException.
    // This surfaces the typed failure without losing the original
    // DioException context (status code, request options, etc.).
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: AppException(failure),
        message: failure.toString(),
      ),
    );
  }

  Failure _mapToFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        final message = _extractMessage(err.response?.data);

        return switch (statusCode) {
          400 => BadRequestFailure(message ?? 'Bad request'),
          401 => const UnauthorizedFailure(),
          403 => const ForbiddenFailure(),
          404 => const NotFoundFailure(),
          409 => ConflictFailure(message ?? 'Conflict'),
          413 => const PayloadTooLargeFailure(),
          415 => const UnsupportedMediaTypeFailure(),
          422 => UnprocessableEntityFailure(message ?? 'Unprocessable entity'),
          429 => const RateLimitedFailure(),
          _ when statusCode >= 500 =>
            ServerFailure(statusCode, message ?? 'Server error'),
          _ => UnknownFailure(
              message ?? err.message ?? 'Unexpected error ($statusCode)',
            ),
        };

      case DioExceptionType.cancel:
        return const UnknownFailure('Request was cancelled');

      case DioExceptionType.badCertificate:
        return const UnknownFailure('Bad SSL certificate');

      case DioExceptionType.unknown:
        return UnknownFailure(err.message ?? 'Unknown error occurred');
    }
  }

  /// Extracts the human-readable `message` field from a JSON error response.
  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return null;
  }
}

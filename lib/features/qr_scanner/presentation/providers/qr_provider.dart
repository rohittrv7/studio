import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../../data/datasources/qr_remote_data_source.dart';
import '../../data/repositories/qr_repository_impl.dart';
import '../../domain/entities/qr_generation_result.dart';
import '../../domain/entities/qr_validation_result.dart';
import '../../domain/repositories/qr_repository.dart';

// ---------------------------------------------------------------------------
// Public error type for an invalid / revoked QR link
// ---------------------------------------------------------------------------

/// Failure emitted when the backend returns HTTP 403 or 410 for a QR token —
/// meaning the gallery link is no longer valid.
class InvalidQrLinkFailure implements Exception {
  const InvalidQrLinkFailure();

  @override
  String toString() => 'InvalidQrLinkFailure: Gallery link is no longer valid';
}

// ---------------------------------------------------------------------------
// Dependency providers
// ---------------------------------------------------------------------------

/// Provides the [QrRemoteDataSource] implementation.
final qrRemoteDataSourceProvider = Provider<QrRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return QrRemoteDataSourceImpl(dio);
});

/// Provides the [QrRepository] implementation.
final qrRepositoryProvider = Provider<QrRepository>((ref) {
  final dataSource = ref.watch(qrRemoteDataSourceProvider);
  return QrRepositoryImpl(dataSource);
});

// ---------------------------------------------------------------------------
// QrValidationNotifier
// ---------------------------------------------------------------------------

/// Manages the async state for a single QR token validation request.
class QrValidationNotifier
    extends StateNotifier<AsyncValue<QrValidationResult?>> {
  QrValidationNotifier(this._repository) : super(const AsyncValue.data(null));

  final QrRepository _repository;

  /// Calls `GET /qr/validate/{token}` and updates state accordingly.
  Future<void> validate(String token) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.validateToken(token);
      state = AsyncValue.data(result);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 403 || statusCode == 410) {
        state = AsyncValue.error(
          const InvalidQrLinkFailure(),
          StackTrace.current,
        );
      } else {
        state = AsyncValue.error(
          Exception('Network error'),
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(Exception('Network error'), st);
    }
  }
}

/// Riverpod provider for [QrValidationNotifier].
final qrValidationProvider = StateNotifierProvider.autoDispose<
    QrValidationNotifier, AsyncValue<QrValidationResult?>>((ref) {
  final repository = ref.watch(qrRepositoryProvider);
  return QrValidationNotifier(repository);
});

// ---------------------------------------------------------------------------
// QrGenerationProvider & Params
// ---------------------------------------------------------------------------

class QrGenerationParam {
  const QrGenerationParam({
    required this.galleryId,
    this.folderId,
    this.mediaFileId,
  });

  final String galleryId;
  final String? folderId;
  final String? mediaFileId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrGenerationParam &&
          runtimeType == other.runtimeType &&
          galleryId == other.galleryId &&
          folderId == other.folderId &&
          mediaFileId == other.mediaFileId;

  @override
  int get hashCode =>
      galleryId.hashCode ^ folderId.hashCode ^ mediaFileId.hashCode;
}

final qrGenerationProvider = FutureProvider.autoDispose
    .family<QrGenerationResult, QrGenerationParam>((ref, param) async {
  final repository = ref.watch(qrRepositoryProvider);
  return repository.generateQr(
    param.galleryId,
    folderId: param.folderId,
    mediaFileId: param.mediaFileId,
  );
});

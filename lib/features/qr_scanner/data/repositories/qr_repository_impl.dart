import '../../domain/entities/qr_generation_result.dart';
import '../../domain/entities/qr_validation_result.dart';
import '../../domain/repositories/qr_repository.dart';
import '../datasources/qr_remote_data_source.dart';

/// Concrete [QrRepository] backed by [QrRemoteDataSource].
class QrRepositoryImpl implements QrRepository {
  const QrRepositoryImpl(this._dataSource);

  final QrRemoteDataSource _dataSource;

  @override
  Future<QrValidationResult> validateToken(String token) {
    return _dataSource.validateToken(token);
  }

  @override
  Future<QrGenerationResult> generateQr(
    String galleryId, {
    String? folderId,
    String? mediaFileId,
  }) {
    return _dataSource.generateQr(
      galleryId,
      folderId: folderId,
      mediaFileId: mediaFileId,
    );
  }
}

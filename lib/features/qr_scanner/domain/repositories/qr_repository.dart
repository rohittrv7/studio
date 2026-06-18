import '../entities/qr_generation_result.dart';
import '../entities/qr_validation_result.dart';

/// Abstract contract for QR-related remote operations.
abstract class QrRepository {
  /// Validates a QR [token] with the backend.
  ///
  /// Returns a [QrValidationResult] on success.
  /// Throws on network / server errors.
  Future<QrValidationResult> validateToken(String token);

  /// Generates a QR code for [galleryId] with optional [folderId] or [mediaFileId].
  Future<QrGenerationResult> generateQr(
    String galleryId, {
    String? folderId,
    String? mediaFileId,
  });
}

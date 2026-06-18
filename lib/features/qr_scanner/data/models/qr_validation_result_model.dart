import '../../domain/entities/qr_validation_result.dart';

/// JSON data model for the `/qr/validate/{token}` response.
class QrValidationResultModel extends QrValidationResult {
  const QrValidationResultModel({
    required super.valid,
    required super.galleryId,
    required super.galleryName,
    super.folderId,
    super.mediaFileId,
  });

  factory QrValidationResultModel.fromJson(Map<String, dynamic> json) {
    return QrValidationResultModel(
      valid: json['valid'] as bool,
      galleryId: json['galleryId'] as String,
      galleryName: json['galleryName'] as String,
      folderId: json['folderId'] as String?,
      mediaFileId: json['mediaFileId'] as String?,
    );
  }
}

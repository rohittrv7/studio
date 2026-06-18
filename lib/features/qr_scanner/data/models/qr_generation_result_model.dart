import '../../domain/entities/qr_generation_result.dart';

/// JSON data model for the `/qr/generate/{galleryId}` response.
class QrGenerationResultModel extends QrGenerationResult {
  const QrGenerationResultModel({
    required super.qrImageUrl,
    required super.token,
    required super.deepLink,
    required super.fallbackUrl,
  });

  factory QrGenerationResultModel.fromJson(Map<String, dynamic> json) {
    return QrGenerationResultModel(
      qrImageUrl: json['qrImageUrl'] as String,
      token: json['token'] as String,
      deepLink: json['deepLink'] as String,
      fallbackUrl: json['fallbackUrl'] as String,
    );
  }
}

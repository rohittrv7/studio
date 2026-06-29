import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/qr_generation_result_model.dart';
import '../models/qr_validation_result_model.dart';

/// Abstract contract for the QR remote data source.
abstract class QrRemoteDataSource {
  /// Calls `GET /qr/validate/{token}` and returns a parsed model.
  Future<QrValidationResultModel> validateToken(String token);

  /// Calls `POST /qr/generate/{galleryId}` with optional query params.
  Future<QrGenerationResultModel> generateQr(
    String galleryId, {
    String? folderId,
    String? mediaFileId,
  });
}

/// Concrete implementation backed by [Dio].
class QrRemoteDataSourceImpl implements QrRemoteDataSource {
  const QrRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<QrValidationResultModel> validateToken(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.qrValidate(token),
    );
    return QrValidationResultModel.fromJson(response.data!);
  }

  @override
  Future<QrGenerationResultModel> generateQr(
    String galleryId, {
    String? folderId,
    String? mediaFileId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (folderId != null) queryParameters['folderId'] = folderId;
    if (mediaFileId != null) queryParameters['mediaFileId'] = mediaFileId;

    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.qrGenerate(galleryId),
      queryParameters: queryParameters,
    );
    return QrGenerationResultModel.fromJson(response.data!);
  }
}

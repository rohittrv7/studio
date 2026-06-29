import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/folder_model.dart';
import '../models/gallery_model.dart';

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

/// Remote data source for the gallery feature.
abstract class GalleryRemoteDataSource {
  /// GET `/galleries?page=X&limit=Y`
  Future<List<GalleryModel>> getGalleries({int page = 1, int limit = 20});

  /// GET `/galleries/:id`
  Future<GalleryModel> getGallery(String id);

  /// POST `/galleries`
  Future<GalleryModel> createGallery(String name);

  /// GET `/galleries/:galleryId/folders`
  Future<List<FolderModel>> getFolderTree(String galleryId);

  /// POST `/galleries/:galleryId/folders`
  Future<FolderModel> createFolder(
    String galleryId, {
    required String name,
    String? parentFolderId,
  });

  /// POST `/galleries/:galleryId/media/upload`
  Future<void> uploadMedia(
    String galleryId, {
    required File file,
    required String mediaType,
    String? folderId,
    void Function(double progress)? onProgress,
  });

  /// GET `/customers`
  Future<List<CustomerModel>> getCustomers();

  /// POST `/customers`
  Future<CustomerModel> createCustomer({
    required String name,
    required String phone,
  });

  /// POST `/galleries/:id/assign`
  Future<void> assignGallery(
    String galleryId, {
    required String customerId,
  });

  /// PATCH `/galleries/:id`
  Future<GalleryModel> updateGallery(
    String id, {
    String? name,
    String? customerId,
    bool? downloadEnabled,
    bool? showcase,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// Dio-backed implementation of [GalleryRemoteDataSource].
class GalleryRemoteDataSourceImpl implements GalleryRemoteDataSource {
  const GalleryRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<GalleryModel>> getGalleries({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.galleries,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    final rawList = data?['data'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(GalleryModel.fromJson)
        .toList();
  }

  @override
  Future<GalleryModel> getGallery(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.gallery(id),
    );
    return GalleryModel.fromJson(response.data!);
  }

  @override
  Future<GalleryModel> createGallery(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.galleries,
      data: {'name': name},
    );
    return GalleryModel.fromJson(response.data!);
  }

  @override
  Future<List<FolderModel>> getFolderTree(String galleryId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.galleryFolders(galleryId),
    );
    final data = response.data;
    final rawList = data?['folders'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => FolderModel.fromJson({...e, 'galleryId': galleryId}))
        .toList();
  }

  @override
  Future<FolderModel> createFolder(
    String galleryId, {
    required String name,
    String? parentFolderId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConstants.galleries}/$galleryId/folders',
      data: {
        'name': name,
        if (parentFolderId != null) 'parentFolderId': parentFolderId,
      },
    );
    return FolderModel.fromJson({...response.data!, 'galleryId': galleryId});
  }

  @override
  Future<void> uploadMedia(
    String galleryId, {
    required File file,
    required String mediaType,
    String? folderId,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      'mediaType': mediaType,
      if (folderId != null) 'folderId': folderId,
    });

    await _dio.post<void>(
      '${ApiConstants.galleries}/$galleryId/media/upload',
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );
  }

  @override
  Future<List<CustomerModel>> getCustomers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.customers,
    );
    final rawList = response.data?['data'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(CustomerModel.fromJson)
        .toList();
  }

  @override
  Future<CustomerModel> createCustomer({
    required String name,
    required String phone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.customers,
      data: {
        'name': name,
        'phone': phone,
      },
    );
    return CustomerModel.fromJson(response.data!);
  }

  @override
  Future<void> assignGallery(
    String galleryId, {
    required String customerId,
  }) async {
    await _dio.post<void>(
      ApiConstants.assignGallery(galleryId),
      data: {
        'customerId': customerId,
      },
    );
  }

  @override
  Future<GalleryModel> updateGallery(
    String id, {
    String? name,
    String? customerId,
    bool? downloadEnabled,
    bool? showcase,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiConstants.gallery(id),
      data: {
        if (name != null) 'name': name,
        if (customerId != null) 'customerId': customerId,
        if (downloadEnabled != null) 'downloadEnabled': downloadEnabled,
        if (showcase != null) 'showcase': showcase,
      },
    );
    return GalleryModel.fromJson(response.data!);
  }
}

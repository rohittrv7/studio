import 'dart:io';
import 'package:dio/dio.dart';

import '../../domain/entities/folder.dart';
import '../../domain/entities/gallery.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../datasources/gallery_local_data_source.dart';
import '../datasources/gallery_remote_data_source.dart';

/// Concrete implementation of [GalleryRepository].
///
/// Fetches data from the remote source, persists it locally in Hive, and
/// falls back to the local cache when the network is unavailable.
class GalleryRepositoryImpl implements GalleryRepository {
  const GalleryRepositoryImpl({
    required GalleryRemoteDataSource remote,
    required GalleryLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final GalleryRemoteDataSource _remote;
  final GalleryLocalDataSource _local;

  // ---------------------------------------------------------------------------
  // getGalleries
  // ---------------------------------------------------------------------------

  @override
  Future<List<Gallery>> getGalleries({int page = 1, int limit = 20}) async {
    try {
      final models = await _remote.getGalleries(page: page, limit: limit);
      await _local.saveGalleries(models);
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      final cached = _local.getGalleries();
      if (cached.isNotEmpty) {
        return cached.map((m) => m.toEntity()).toList();
      }
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // getGallery
  // ---------------------------------------------------------------------------

  @override
  Future<Gallery> getGallery(String id) async {
    try {
      final model = await _remote.getGallery(id);
      await _local.saveGallery(model);
      return model.toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const GalleryException('Gallery not found');
      }
      final cached = _local.getGallery(id);
      if (cached != null) {
        return cached.toEntity();
      }
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // getFolderTree
  // ---------------------------------------------------------------------------

  @override
  Future<List<Folder>> getFolderTree(String galleryId) async {
    try {
      final models = await _remote.getFolderTree(galleryId);
      await _local.saveFolderTree(galleryId, models);
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      final cached = _local.getFolderTree(galleryId);
      if (cached.isNotEmpty) {
        return cached.map((m) => m.toEntity()).toList();
      }
      throw _mapDioException(e);
    }
  }

  @override
  Future<Folder> createFolder(
    String galleryId, {
    required String name,
    String? parentFolderId,
  }) async {
    try {
      final model = await _remote.createFolder(
        galleryId,
        name: name,
        parentFolderId: parentFolderId,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Gallery> createGallery(String name) async {
    try {
      final model = await _remote.createGallery(name);
      await _local.saveGallery(model);
      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> uploadMedia(
    String galleryId, {
    required File file,
    required String mediaType,
    String? folderId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _remote.uploadMedia(
        galleryId,
        file: file,
        mediaType: mediaType,
        folderId: folderId,
        onProgress: onProgress,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<List<Customer>> getCustomers() async {
    try {
      final models = await _remote.getCustomers();
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Customer> createCustomer({
    required String name,
    required String phone,
  }) async {
    try {
      final model = await _remote.createCustomer(name: name, phone: phone);
      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> assignGallery(
    String galleryId, {
    required String customerId,
    bool? downloadEnabled,
  }) async {
    try {
      await _remote.assignGallery(galleryId, customerId: customerId, downloadEnabled: downloadEnabled);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Gallery> updateGallery(
    String id, {
    String? name,
    String? customerId,
    bool? downloadEnabled,
    bool? showcase,
  }) async {
    try {
      final model = await _remote.updateGallery(
        id,
        name: name,
        customerId: customerId,
        downloadEnabled: downloadEnabled,
        showcase: showcase,
      );
      await _local.saveGallery(model);
      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  GalleryException _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const GalleryException(
        'No internet connection. Please check your network.',
      );
    }
    final statusCode = e.response?.statusCode ?? 0;
    switch (statusCode) {
      case 401:
        return const GalleryException('Authentication required.');
      case 404:
        return const GalleryException('Gallery not found.');
      default:
        return const GalleryException(
          'An unexpected error occurred. Please try again.',
        );
    }
  }
}

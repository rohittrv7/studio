import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/folder_model.dart';
import '../models/gallery_model.dart';

/// Local cache data source for the gallery feature backed by Hive.
class GalleryLocalDataSource {
  const GalleryLocalDataSource({
    required Box<dynamic> galleryBox,
    required Box<dynamic> folderBox,
  })  : _galleryBox = galleryBox,
        _folderBox = folderBox;

  final Box<dynamic> _galleryBox;
  final Box<dynamic> _folderBox;

  // ---------------------------------------------------------------------------
  // Gallery list
  // ---------------------------------------------------------------------------

  /// Persists [galleries] as a JSON list under the key `'galleries'`.
  Future<void> saveGalleries(List<GalleryModel> galleries) async {
    final encoded = jsonEncode(galleries.map((g) => g.toJson()).toList());
    await _galleryBox.put('galleries', encoded);
  }

  /// Returns the cached list of galleries, or an empty list if not present.
  List<GalleryModel> getGalleries() {
    final raw = _galleryBox.get('galleries');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GalleryModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Single gallery
  // ---------------------------------------------------------------------------

  /// Persists a single [gallery] under the key `'gallery_${gallery.id}'`.
  Future<void> saveGallery(GalleryModel gallery) async {
    final encoded = jsonEncode(gallery.toJson());
    await _galleryBox.put('gallery_${gallery.id}', encoded);
  }

  /// Returns the cached [GalleryModel] for [id], or null if not cached.
  GalleryModel? getGallery(String id) {
    final raw = _galleryBox.get('gallery_$id');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return null;
      return GalleryModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Folder tree
  // ---------------------------------------------------------------------------

  /// Persists [folders] under the key `'folders_$galleryId'`.
  Future<void> saveFolderTree(
    String galleryId,
    List<FolderModel> folders,
  ) async {
    final encoded = jsonEncode(folders.map((f) => f.toJson()).toList());
    await _folderBox.put('folders_$galleryId', encoded);
  }

  /// Returns the cached folder tree for [galleryId], or an empty list.
  List<FolderModel> getFolderTree(String galleryId) {
    final raw = _folderBox.get('folders_$galleryId');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FolderModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

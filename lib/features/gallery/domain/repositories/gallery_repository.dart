import 'dart:io';
import '../entities/folder.dart';
import '../entities/gallery.dart';

/// Abstract contract for gallery data operations.
abstract class GalleryRepository {
  /// Returns a paginated list of galleries.
  Future<List<Gallery>> getGalleries({int page = 1, int limit = 20});

  /// Returns a single gallery by [id].
  Future<Gallery> getGallery(String id);

  /// Returns the folder tree for a gallery identified by [galleryId].
  Future<List<Folder>> getFolderTree(String galleryId);

  /// Creates a new gallery.
  Future<Gallery> createGallery(String name);

  /// Creates a new folder in a gallery.
  Future<Folder> createFolder(
    String galleryId, {
    required String name,
    String? parentFolderId,
  });

  /// Uploads a photo or video to a gallery.
  Future<void> uploadMedia(
    String galleryId, {
    required File file,
    required String mediaType,
    String? folderId,
    void Function(double progress)? onProgress,
  });

  /// Returns all customers for the studio owner.
  Future<List<Customer>> getCustomers();

  /// Creates a new customer.
  Future<Customer> createCustomer({
    required String name,
    required String phone,
  });

  /// Assigns a customer to a gallery.
  Future<void> assignGallery(
    String galleryId, {
    required String customerId,
    bool? downloadEnabled,
  });

  /// Updates a gallery.
  Future<Gallery> updateGallery(
    String id, {
    String? name,
    String? customerId,
    bool? downloadEnabled,
    bool? showcase,
  });
}

/// Thrown by [GalleryRepository] implementations to surface gallery-specific errors.
class GalleryException implements Exception {
  const GalleryException(this.message);

  final String message;

  @override
  String toString() => 'GalleryException: $message';
}

/// Type of media file.
enum MediaType { photo, video }

/// Domain entity representing a single media file in a gallery.
class MediaFile {
  const MediaFile({
    required this.id,
    required this.galleryId,
    this.folderId,
    required this.secureUrl,
    required this.thumbnailUrl,
    required this.mediaType,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.durationSeconds,
    required this.downloadPermitted,
    required this.downloadCount,
    required this.createdAt,
  });

  final String id;
  final String galleryId;
  final String? folderId;
  final String secureUrl;
  final String thumbnailUrl;
  final MediaType mediaType;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final double? durationSeconds;
  final bool downloadPermitted;
  final int downloadCount;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MediaFile(id: $id, galleryId: $galleryId, mediaType: $mediaType)';
}

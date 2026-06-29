import '../../../media/domain/entities/media_file.dart';

/// Domain entity representing a favorited media file.
class Favorite {
  const Favorite({
    required this.id,
    required this.mediaFileId,
    required this.createdAt,
    this.mediaFile,
  });

  final String id;
  final String mediaFileId;
  final DateTime createdAt;
  final MediaFile? mediaFile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Favorite(id: $id, mediaFileId: $mediaFileId)';
}

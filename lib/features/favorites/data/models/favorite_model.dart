import '../../../media/data/models/media_file_model.dart';
import '../../domain/entities/favorite.dart';

/// JSON model for a favorite record from the API.
class FavoriteModel {
  const FavoriteModel({
    required this.id,
    required this.mediaFileId,
    required this.createdAt,
    this.mediaFile,
  });

  final String id;
  final String mediaFileId;
  final DateTime createdAt;
  final MediaFileModel? mediaFile;

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    final mediaFileJson = json['mediaFile'];
    return FavoriteModel(
      id: json['id'] as String,
      mediaFileId: json['mediaFileId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      mediaFile: mediaFileJson is Map<String, dynamic>
          ? MediaFileModel.fromJson(mediaFileJson)
          : null,
    );
  }

  /// Maps this model to a domain [Favorite] entity.
  Favorite toEntity() => Favorite(
        id: id,
        mediaFileId: mediaFileId,
        createdAt: createdAt,
        mediaFile: mediaFile?.toEntity(),
      );
}

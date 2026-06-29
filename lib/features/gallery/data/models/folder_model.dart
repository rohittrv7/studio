import '../../domain/entities/folder.dart';

/// JSON model for a folder object from the API.
/// Children are parsed recursively.
class FolderModel {
  const FolderModel({
    required this.id,
    required this.galleryId,
    this.parentFolderId,
    required this.name,
    required this.depth,
    required this.mediaCount,
    this.children = const [],
  });

  final String id;
  final String galleryId;
  final String? parentFolderId;
  final String name;
  final int depth;
  final int mediaCount;
  final List<FolderModel> children;

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final children = rawChildren is List
        ? rawChildren
            .whereType<Map<String, dynamic>>()
            .map(FolderModel.fromJson)
            .toList()
        : <FolderModel>[];

    return FolderModel(
      id: json['id'] as String,
      galleryId: (json['galleryId'] as String?) ?? '',
      parentFolderId: json['parentFolderId'] as String?,
      name: json['name'] as String,
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
      children: children,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'galleryId': galleryId,
        if (parentFolderId != null) 'parentFolderId': parentFolderId,
        'name': name,
        'depth': depth,
        'mediaCount': mediaCount,
        'children': children.map((c) => c.toJson()).toList(),
      };

  /// Maps this model to a domain [Folder] entity (recursively).
  Folder toEntity() => Folder(
        id: id,
        galleryId: galleryId,
        parentFolderId: parentFolderId,
        name: name,
        depth: depth,
        mediaCount: mediaCount,
        children: children.map((c) => c.toEntity()).toList(),
      );
}

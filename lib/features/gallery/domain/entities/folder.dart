/// Domain entity representing a folder inside a gallery.
class Folder {
  const Folder({
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
  final List<Folder> children;

  @override
  String toString() =>
      'Folder(id: $id, name: $name, galleryId: $galleryId, depth: $depth)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

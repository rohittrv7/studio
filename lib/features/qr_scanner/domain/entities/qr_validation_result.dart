/// Domain entity representing the result of validating a QR gallery token.
class QrValidationResult {
  const QrValidationResult({
    required this.valid,
    required this.galleryId,
    required this.galleryName,
    this.folderId,
    this.mediaFileId,
  });

  final bool valid;
  final String galleryId;
  final String galleryName;
  final String? folderId;
  final String? mediaFileId;
}

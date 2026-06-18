import '../../domain/entities/media_file.dart';

/// JSON model for a media file object from the API.
class MediaFileModel {
  const MediaFileModel({
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

  factory MediaFileModel.fromJson(Map<String, dynamic> json) {
    return MediaFileModel(
      id: json['id'] as String,
      galleryId: (json['galleryId'] as String?) ?? '',
      folderId: json['folderId'] as String?,
      secureUrl: json['secureUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      mediaType: (json['mediaType'] as String?)?.toLowerCase() == 'video'
          ? MediaType.video
          : MediaType.photo,
      mimeType: json['mimeType'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      downloadPermitted: (json['downloadPermitted'] as bool?) ?? false,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'galleryId': galleryId,
        if (folderId != null) 'folderId': folderId,
        'secureUrl': secureUrl,
        'thumbnailUrl': thumbnailUrl,
        'mediaType': mediaType == MediaType.video ? 'video' : 'photo',
        'mimeType': mimeType,
        'fileSize': fileSize,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'downloadPermitted': downloadPermitted,
        'downloadCount': downloadCount,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Maps this model to a domain [MediaFile] entity.
  MediaFile toEntity() => MediaFile(
        id: id,
        galleryId: galleryId,
        folderId: folderId,
        secureUrl: secureUrl,
        thumbnailUrl: thumbnailUrl,
        mediaType: mediaType,
        mimeType: mimeType,
        fileSize: fileSize,
        width: width,
        height: height,
        durationSeconds: durationSeconds,
        downloadPermitted: downloadPermitted,
        downloadCount: downloadCount,
        createdAt: createdAt,
      );
}

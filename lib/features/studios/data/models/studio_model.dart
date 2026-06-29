class StudioModel {
  const StudioModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.profilePhoto,
    this.studioName,
    this.location,
    this.description,
    this.plans = const [],
    this.showcaseGalleries = const [],
    this.demoMedia = const [],
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? profilePhoto;
  final String? studioName;
  final String? location;
  final String? description;
  final List<PlanModel> plans;
  final List<ShowcaseGalleryModel> showcaseGalleries;
  final List<DemoMediaModel> demoMedia;

  factory StudioModel.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'];
    final plans = rawPlans is List
        ? rawPlans.map((p) => PlanModel.fromJson(p as Map<String, dynamic>)).toList()
        : const <PlanModel>[];

    final rawShowcase = json['showcaseGalleries'];
    final showcaseGalleries = rawShowcase is List
        ? rawShowcase.map((s) => ShowcaseGalleryModel.fromJson(s as Map<String, dynamic>)).toList()
        : const <ShowcaseGalleryModel>[];

    final rawDemo = json['demoMedia'];
    final demoMedia = rawDemo is List
        ? rawDemo.map((d) => DemoMediaModel.fromJson(d as Map<String, dynamic>)).toList()
        : const <DemoMediaModel>[];

    return StudioModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      studioName: json['studioName'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      plans: plans,
      showcaseGalleries: showcaseGalleries,
      demoMedia: demoMedia,
    );
  }
}

class PlanModel {
  const PlanModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.price,
    required this.description,
    this.duration,
    this.deliverables,
  });

  final String id;
  final String userId;
  final String name;
  final double price;
  final String description;
  final String? duration;
  final String? deliverables;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String,
      duration: json['duration'] as String?,
      deliverables: json['deliverables'] as String?,
    );
  }
}

class ShowcaseGalleryModel {
  const ShowcaseGalleryModel({
    required this.id,
    required this.name,
    required this.mediaCount,
    required this.coverUrl,
    this.mediaFiles = const [],
  });

  final String id;
  final String name;
  final int mediaCount;
  final String coverUrl;
  final List<ShowcaseMediaModel> mediaFiles;

  factory ShowcaseGalleryModel.fromJson(Map<String, dynamic> json) {
    final countMap = json['_count'] as Map<String, dynamic>?;
    final mediaCount = countMap?['mediaFiles'] as int? ?? 0;
    
    final rawMedia = json['mediaFiles'] as List?;
    final mediaFiles = rawMedia != null 
        ? rawMedia.map((m) => ShowcaseMediaModel.fromJson(m as Map<String, dynamic>)).toList()
        : const <ShowcaseMediaModel>[];

    final coverUrl = mediaFiles.isNotEmpty ? mediaFiles.first.thumbnailUrl : '';

    return ShowcaseGalleryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      mediaCount: mediaCount,
      coverUrl: coverUrl,
      mediaFiles: mediaFiles,
    );
  }
}

class ShowcaseMediaModel {
  const ShowcaseMediaModel({
    required this.secureUrl,
    required this.thumbnailUrl,
  });

  final String secureUrl;
  final String thumbnailUrl;

  factory ShowcaseMediaModel.fromJson(Map<String, dynamic> json) {
    return ShowcaseMediaModel(
      secureUrl: json['secureUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }
}

class DemoMediaModel {
  const DemoMediaModel({
    required this.id,
    required this.secureUrl,
    required this.thumbnailUrl,
    required this.mediaType,
  });

  final String id;
  final String secureUrl;
  final String thumbnailUrl;
  final String mediaType; // "PHOTO" | "VIDEO"

  factory DemoMediaModel.fromJson(Map<String, dynamic> json) {
    return DemoMediaModel(
      id: json['id'] as String,
      secureUrl: json['secureUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      mediaType: json['mediaType'] as String,
    );
  }
}

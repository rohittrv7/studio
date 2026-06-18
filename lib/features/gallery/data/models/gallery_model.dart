import '../../domain/entities/gallery.dart';

/// JSON model for the customer nested inside a gallery response.
class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: (json['phone'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  Customer toEntity() => Customer(id: id, name: name, phone: phone);
}

/// JSON model for a gallery object from the API.
class GalleryModel {
  const GalleryModel({
    required this.id,
    required this.name,
    this.customerId,
    required this.mediaCount,
    this.coverThumbnailUrl,
    required this.downloadEnabled,
    this.customer,
  });

  final String id;
  final String name;
  final String? customerId;
  final int mediaCount;
  final String? coverThumbnailUrl;
  final bool downloadEnabled;
  final CustomerModel? customer;

  factory GalleryModel.fromJson(Map<String, dynamic> json) {
    final customerJson = json['customer'];
    return GalleryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      customerId: json['customerId'] as String?,
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      downloadEnabled: (json['downloadEnabled'] as bool?) ?? false,
      customer: customerJson is Map<String, dynamic>
          ? CustomerModel.fromJson(customerJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (customerId != null) 'customerId': customerId,
        'mediaCount': mediaCount,
        if (coverThumbnailUrl != null) 'coverThumbnailUrl': coverThumbnailUrl,
        'downloadEnabled': downloadEnabled,
        if (customer != null) 'customer': customer!.toJson(),
      };

  /// Maps this model to a domain [Gallery] entity.
  Gallery toEntity() => Gallery(
        id: id,
        name: name,
        customerId: customerId,
        mediaCount: mediaCount,
        coverThumbnailUrl: coverThumbnailUrl,
        downloadEnabled: downloadEnabled,
        customer: customer?.toEntity(),
      );
}

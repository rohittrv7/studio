import '../../domain/entities/auth_user.dart';

/// JSON model for the `/auth/verify-otp` and `/auth/refresh` responses.
class AuthResponseModel {
  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Maps this model to a domain [AuthUser] entity.
  AuthUser toEntity() => user.toEntity();
}

/// Nested user object inside [AuthResponseModel].
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profilePhoto,
    required this.role,
    required this.galleryIds,
    this.studioName,
    this.location,
    this.description,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? profilePhoto;

  /// `'studio_owner'` or `'customer'`
  final String role;
  final List<String> galleryIds;

  final String? studioName;
  final String? location;
  final String? description;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawIds = json['galleryIds'];
    final galleryIds = rawIds is List
        ? rawIds.cast<String>()
        : const <String>[];

    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      role: (json['role'] as String?) ?? '',
      galleryIds: galleryIds,
      studioName: json['studioName'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Maps to domain [AuthUser].
  AuthUser toEntity() => AuthUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        profilePhoto: profilePhoto,
        role: role,
        galleryIds: galleryIds,
        studioName: studioName,
        location: location,
        description: description,
      );
}

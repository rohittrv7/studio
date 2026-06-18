/// Domain entity representing an authenticated user (studio owner or customer).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.profilePhoto,
    required this.role,
    required this.galleryIds,
  });

  /// Unique identifier from the backend.
  final String id;

  /// Display name of the user.
  final String name;

  /// Email of the user.
  final String? email;

  /// Profile photo URL of the user.
  final String? profilePhoto;

  /// Role: either `'studio_owner'` or `'customer'`.
  final String role;

  /// List of gallery IDs accessible to this user (relevant for customers).
  final List<String> galleryIds;

  bool get isStudioOwner => role == 'studio_owner';
  bool get isCustomer => role == 'customer';

  @override
  String toString() =>
      'AuthUser(id: $id, name: $name, email: $email, profilePhoto: $profilePhoto, role: $role, galleryIds: $galleryIds)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          profilePhoto == other.profilePhoto &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, email, profilePhoto, role);
}

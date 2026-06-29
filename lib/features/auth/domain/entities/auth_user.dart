/// Domain entity representing an authenticated user (studio owner or customer).
class AuthUser {
  const AuthUser({
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

  /// Unique identifier from the backend.
  final String id;

  /// Display name of the user.
  final String name;

  /// Email of the user.
  final String? email;

  /// Phone of the user.
  final String? phone;

  /// Profile photo URL of the user.
  final String? profilePhoto;

  /// Role: either `'studio_owner'` or `'customer'`.
  final String role;

  /// List of gallery IDs accessible to this user (relevant for customers).
  final List<String> galleryIds;

  final String? studioName;
  final String? location;
  final String? description;

  bool get isStudioOwner => role == 'studio_owner';
  bool get isCustomer => role == 'customer';

  @override
  String toString() =>
      'AuthUser(id: $id, name: $name, email: $email, phone: $phone, profilePhoto: $profilePhoto, role: $role, galleryIds: $galleryIds, studioName: $studioName, location: $location, description: $description)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          profilePhoto == other.profilePhoto &&
          role == other.role &&
          studioName == other.studioName &&
          location == other.location &&
          description == other.description;

  @override
  int get hashCode => Object.hash(id, name, email, phone, profilePhoto, role, studioName, location, description);
}

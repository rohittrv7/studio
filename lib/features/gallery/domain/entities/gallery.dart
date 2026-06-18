/// Domain entity representing a customer.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  @override
  String toString() => 'Customer(id: $id, name: $name, phone: $phone)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Domain entity representing a photo gallery.
class Gallery {
  const Gallery({
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
  final Customer? customer;

  @override
  String toString() =>
      'Gallery(id: $id, name: $name, mediaCount: $mediaCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gallery &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

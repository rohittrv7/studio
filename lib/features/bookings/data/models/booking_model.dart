import '../../../studios/data/models/studio_model.dart';

class BookingModel {
  const BookingModel({
    required this.id,
    required this.customerId,
    required this.studioOwnerId,
    required this.planId,
    required this.bookingDate,
    required this.shootAddress,
    required this.totalPrice,
    required this.advancePaid,
    required this.status,
    required this.createdAt,
    this.plan,
    this.customer,
    this.studioOwner,
  });

  final String id;
  final String customerId;
  final String studioOwnerId;
  final String planId;
  final DateTime bookingDate;
  final String shootAddress;
  final double totalPrice;
  final double advancePaid;
  final String status; // PENDING, CONFIRMED, REJECTED, COMPLETED
  final DateTime createdAt;
  final PlanModel? plan;
  final BookingClientModel? customer;
  final BookingStudioModel? studioOwner;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      studioOwnerId: json['studioOwnerId'] as String,
      planId: json['planId'] as String,
      bookingDate: DateTime.parse(json['bookingDate'] as String),
      shootAddress: json['shootAddress'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      advancePaid: (json['advancePaid'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      plan: json['plan'] != null ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>) : null,
      customer: json['customer'] != null ? BookingClientModel.fromJson(json['customer'] as Map<String, dynamic>) : null,
      studioOwner: json['studioOwner'] != null ? BookingStudioModel.fromJson(json['studioOwner'] as Map<String, dynamic>) : null,
    );
  }
}

class BookingClientModel {
  const BookingClientModel({
    required this.name,
    required this.phone,
    this.profilePhoto,
  });

  final String name;
  final String phone;
  final String? profilePhoto;

  factory BookingClientModel.fromJson(Map<String, dynamic> json) {
    return BookingClientModel(
      name: json['name'] as String,
      phone: json['phone'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );
  }
}

class BookingStudioModel {
  const BookingStudioModel({
    required this.name,
    this.studioName,
    required this.phone,
    this.profilePhoto,
  });

  final String name;
  final String? studioName;
  final String phone;
  final String? profilePhoto;

  factory BookingStudioModel.fromJson(Map<String, dynamic> json) {
    return BookingStudioModel(
      name: json['name'] as String,
      studioName: json['studioName'] as String?,
      phone: json['phone'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );
  }
}

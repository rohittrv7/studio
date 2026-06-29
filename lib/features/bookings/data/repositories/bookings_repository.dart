import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_providers.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../studios/data/models/studio_model.dart';
import '../models/booking_model.dart';

class BookingsRepository {
  const BookingsRepository(this._dio);
  final Dio _dio;

  // ─── Pricing Plans ─────────────────────────────────────────────────────────

  Future<PlanModel> createPlan({
    required String name,
    required double price,
    required String description,
    String? duration,
    String? deliverables,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.plans,
      data: {
        'name': name,
        'price': price,
        'description': description,
        if (duration != null) 'duration': duration,
        if (deliverables != null) 'deliverables': deliverables,
      },
    );
    return PlanModel.fromJson(response.data!);
  }

  Future<List<PlanModel>> getMyPlans() async {
    final response = await _dio.get<List<dynamic>>(
      '${ApiConstants.plans}/my-plans',
    );
    return response.data!
        .map((p) => PlanModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePlan(String id) async {
    await _dio.delete<void>(
      '${ApiConstants.plans}/$id',
    );
  }

  // ─── Bookings ──────────────────────────────────────────────────────────────

  Future<BookingModel> createBooking({
    required String planId,
    required String bookingDate,
    required String shootAddress,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.bookings,
      data: {
        'planId': planId,
        'bookingDate': bookingDate,
        'shootAddress': shootAddress,
      },
    );
    return BookingModel.fromJson(response.data!);
  }

  Future<List<BookingModel>> getMyBookings() async {
    final response = await _dio.get<List<dynamic>>(
      ApiConstants.myBookings,
    );
    return response.data!
        .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiConstants.bookingStatus(bookingId),
      data: {'status': status},
    );
    return BookingModel.fromJson(response.data!);
  }

  Future<BookingModel> payBooking({
    required String bookingId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/pay',
    );
    return BookingModel.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> createPaymentOrder(String bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/payment-order',
    );
    return response.data!;
  }

  Future<BookingModel> verifyPayment({
    required String bookingId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/verify-payment',
      data: {
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    return BookingModel.fromJson(response.data!);
  }

  Future<BookingModel> submitManualPayment({
    required String bookingId,
    required String transactionRef,
    String? paymentScreenshot,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/submit-payment',
      data: {
        'transactionRef': transactionRef,
        if (paymentScreenshot != null) 'paymentScreenshot': paymentScreenshot,
      },
    );
    return BookingModel.fromJson(response.data!);
  }
}

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(ref.watch(dioProvider));
});

// A StateNotifierProvider to manage plans list
class PlansListNotifier extends StateNotifier<AsyncValue<List<PlanModel>>> {
  PlansListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadPlans();
  }

  final BookingsRepository _repository;

  Future<void> loadPlans() async {
    state = const AsyncValue.loading();
    try {
      final plans = await _repository.getMyPlans();
      state = AsyncValue.data(plans);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createPlan(
    String name,
    double price,
    String description, {
    String? duration,
    String? deliverables,
  }) async {
    try {
      final newPlan = await _repository.createPlan(
        name: name,
        price: price,
        description: description,
        duration: duration,
        deliverables: deliverables,
      );
      state.whenData((plans) {
        state = AsyncValue.data([newPlan, ...plans]);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePlan(String id) async {
    try {
      await _repository.deletePlan(id);
      state.whenData((plans) {
        state = AsyncValue.data(plans.where((p) => p.id != id).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

final plansListProvider = StateNotifierProvider<PlansListNotifier, AsyncValue<List<PlanModel>>>((ref) {
  return PlansListNotifier(ref.watch(bookingsRepositoryProvider));
});

// A StateNotifierProvider to manage bookings list
class BookingsListNotifier extends StateNotifier<AsyncValue<List<BookingModel>>> {
  BookingsListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadBookings();
  }

  final BookingsRepository _repository;

  Future<void> loadBookings() async {
    state = const AsyncValue.loading();
    try {
      final bookings = await _repository.getMyBookings();
      state = AsyncValue.data(bookings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createBooking(String planId, String bookingDate, String shootAddress) async {
    try {
      await _repository.createBooking(
        planId: planId,
        bookingDate: bookingDate,
        shootAddress: shootAddress,
      );
      loadBookings();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _repository.updateBookingStatus(bookingId: bookingId, status: status);
      state.whenData((bookings) {
        state = AsyncValue.data(bookings.map((b) {
          if (b.id == bookingId) {
            return BookingModel(
              id: b.id,
              customerId: b.customerId,
              studioOwnerId: b.studioOwnerId,
              planId: b.planId,
              bookingDate: b.bookingDate,
              shootAddress: b.shootAddress,
              totalPrice: b.totalPrice,
              advancePaid: b.advancePaid,
              status: status,
              isPaid: b.isPaid,
              createdAt: b.createdAt,
              plan: b.plan,
              customer: b.customer,
              studioOwner: b.studioOwner,
            );
          }
          return b;
        }).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> payBooking(String bookingId) async {
    try {
      final updated = await _repository.payBooking(bookingId: bookingId);
      state.whenData((bookings) {
        state = AsyncValue.data(bookings.map((b) => b.id == bookingId ? updated : b).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPayment(String bookingId, String paymentId, String signature) async {
    try {
      final updated = await _repository.verifyPayment(
        bookingId: bookingId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      state.whenData((bookings) {
        state = AsyncValue.data(bookings.map((b) => b.id == bookingId ? updated : b).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitManualPayment({
    required String bookingId,
    required String transactionRef,
    String? paymentScreenshot,
  }) async {
    try {
      final updated = await _repository.submitManualPayment(
        bookingId: bookingId,
        transactionRef: transactionRef,
        paymentScreenshot: paymentScreenshot,
      );
      state.whenData((bookings) {
        state = AsyncValue.data(bookings.map((b) => b.id == bookingId ? updated : b).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bookingsListProvider = StateNotifierProvider<BookingsListNotifier, AsyncValue<List<BookingModel>>>((ref) {
  return BookingsListNotifier(ref.watch(bookingsRepositoryProvider));
});

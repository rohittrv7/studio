import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_providers.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/studio_model.dart';

class StudiosRepository {
  const StudiosRepository(this._dio);
  final Dio _dio;

  Future<List<StudioModel>> getStudios({String? location, String? bookingDate}) async {
    final queryParameters = <String, dynamic>{};
    if (location != null && location.isNotEmpty) {
      queryParameters['location'] = location;
    }
    if (bookingDate != null && bookingDate.isNotEmpty) {
      queryParameters['bookingDate'] = bookingDate;
    }
    final response = await _dio.get<List<dynamic>>(
      ApiConstants.studios,
      queryParameters: queryParameters,
    );
    return response.data!
        .map((s) => StudioModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }


  Future<StudioModel> getStudioDetails(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.studio(id),
    );
    return StudioModel.fromJson(response.data!);
  }
}

final studiosRepositoryProvider = Provider<StudiosRepository>((ref) {
  return StudiosRepository(ref.watch(dioProvider));
});

class StudioSearchQuery {
  final String? location;
  final String? bookingDate;

  const StudioSearchQuery({this.location, this.bookingDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioSearchQuery &&
          runtimeType == other.runtimeType &&
          location == other.location &&
          bookingDate == other.bookingDate;

  @override
  int get hashCode => location.hashCode ^ bookingDate.hashCode;
}

final studiosListProvider = FutureProvider.family<List<StudioModel>, StudioSearchQuery>((ref, query) async {
  return ref.watch(studiosRepositoryProvider).getStudios(
    location: query.location,
    bookingDate: query.bookingDate,
  );
});


final studioDetailsProvider = FutureProvider.family<StudioModel, String>((ref, id) async {
  return ref.watch(studiosRepositoryProvider).getStudioDetails(id);
});

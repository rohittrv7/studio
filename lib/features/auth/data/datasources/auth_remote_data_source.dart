import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/auth_response_model.dart';

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

/// Remote data source for the auth feature.
abstract class AuthRemoteDataSource {
  /// POST `/auth/send-otp`
  Future<String> sendOtp({
    required String phone,
    required String userType,
  });

  /// POST `/auth/verify-otp`
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  });

  /// POST `/auth/refresh`
  Future<AuthResponseModel> refreshToken({required String refreshToken});

  /// POST `/auth/logout`
  Future<void> logout({required String refreshToken});

  /// POST `/auth/register-fcm-token`
  Future<void> registerFcmToken({
    required String token,
    required String platform,
  });

  /// GET `/auth/profile`
  Future<UserModel> getProfile();

  /// PATCH `/auth/profile`
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? profilePhoto,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/// Dio-backed implementation of [AuthRemoteDataSource].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<String> sendOtp({
    required String phone,
    required String userType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.sendOtp,
      data: {'phone': phone, 'userType': userType},
    );
    final data = response.data;
    return (data?['message'] as String?) ?? 'OTP sent successfully';
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone,
      'userType': userType,
    };
    if (idToken != null) payload['idToken'] = idToken;
    if (otp != null) payload['otp'] = otp;

    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.verifyOtp,
      data: payload,
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<AuthResponseModel> refreshToken({required String refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.refreshToken,
      data: {'refreshToken': refreshToken},
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _dio.post<void>(
      ApiConstants.logout,
      data: {'refreshToken': refreshToken},
    );
  }

  @override
  Future<void> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    await _dio.post<void>(
      ApiConstants.registerFcmToken,
      data: {'token': token, 'platform': platform},
    );
  }

  @override
  Future<UserModel> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/profile');
    return UserModel.fromJson(response.data!);
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? profilePhoto,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/auth/profile',
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (profilePhoto != null) 'profilePhoto': profilePhoto,
      },
    );
    return UserModel.fromJson(response.data!);
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Concrete implementation of [AuthRepository].
///
/// Delegates network calls to [AuthRemoteDataSource], maps models to entities,
/// persists tokens in [HiveStorage], and converts [DioException]s to
/// [AuthException]s.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required HiveStorage storage,
  })  : _remote = remoteDataSource,
        _storage = storage;

  final AuthRemoteDataSource _remote;
  final HiveStorage _storage;

  @override
  Future<String> sendOtp({
    required String phone,
    required String userType,
  }) async {
    try {
      return await _remote.sendOtp(phone: phone, userType: userType);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<AuthUser> verifyOtp({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  }) async {
    try {
      final model = await _remote.verifyOtp(
        phone: phone,
        idToken: idToken,
        otp: otp,
        userType: userType,
      );

      // Persist tokens immediately after successful verification.
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      await _storage.saveProfile(
        name: model.user.name,
        email: model.user.email,
        profilePhoto: model.user.profilePhoto,
        studioName: model.user.studioName,
        location: model.user.location,
        description: model.user.description,
      );

      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> refreshTokens({required String refreshToken}) async {
    try {
      final model = await _remote.refreshToken(refreshToken: refreshToken);
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    final accessToken = _storage.getAccessToken();
    await _storage.clearTokens();
    try {
      await _remote.logout(refreshToken: refreshToken, accessToken: accessToken);
    } on DioException catch (e) {
      // Best-effort logout: if the server call fails, still clear local tokens.
      // Rethrow only unrecoverable network failures so the UI can show feedback.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw _mapDioException(e);
      }
      // Ignore 401/404 on logout — token may already be revoked.
    }
  }

  @override
  Future<void> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _remote.registerFcmToken(token: token, platform: platform);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<AuthUser> getProfile() async {
    try {
      final model = await _remote.getProfile();
      await _storage.saveProfile(
        name: model.name,
        email: model.email,
        profilePhoto: model.profilePhoto,
        studioName: model.studioName,
        location: model.location,
        description: model.description,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Map<String, dynamic> _getUserDetailsFromToken() {
    try {
      final token = _storage.getAccessToken();
      if (token == null || token.isEmpty) return {};

      final parts = token.split('.');
      if (parts.length != 3) return {};

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(resp) as Map<String, dynamic>;
      return {
        'role': data['role'] as String?,
        'galleryIds': List<String>.from(data['galleryIds'] ?? const <String>[]),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<AuthUser> updateProfile({
    String? name,
    String? email,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  }) async {
    try {
      final model = await _remote.updateProfile(
        name: name,
        email: email,
        profilePhoto: profilePhoto,
        studioName: studioName,
        location: location,
        description: description,
      );
      await _storage.saveProfile(
        name: model.name,
        email: model.email,
        profilePhoto: model.profilePhoto,
        studioName: model.studioName,
        location: model.location,
        description: model.description,
      );
      
      final entity = model.toEntity();
      if (entity.role.isEmpty || entity.galleryIds.isEmpty) {
        final tokenDetails = _getUserDetailsFromToken();
        return AuthUser(
          id: entity.id,
          name: entity.name,
          email: entity.email,
          profilePhoto: entity.profilePhoto,
          role: entity.role.isEmpty ? (tokenDetails['role'] as String? ?? '') : entity.role,
          galleryIds: entity.galleryIds.isEmpty ? (tokenDetails['galleryIds'] as List<String>? ?? const []) : entity.galleryIds,
        );
      }
      return entity;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  /// Maps a [DioException] to an [AuthException] with a user-facing message.
  AuthException _mapDioException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final responseData = e.response?.data;
    final serverMessage = _extractMessage(responseData);

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AuthException(
        'No internet connection. Please check your network.',
      );
    }

    switch (statusCode) {
      case 401:
        return AuthException(
          serverMessage ?? 'Invalid OTP, please try again.',
        );
      case 404:
        return AuthException(
          serverMessage ?? 'Account not found.',
        );
      case 429:
        // Extract lock duration from response if available.
        final lockDuration = _extractLockDuration(responseData);
        return AuthException(
          serverMessage ?? 'Account locked due to too many failed attempts.',
          isLocked: true,
          lockDurationSeconds: lockDuration,
        );
      default:
        return AuthException(
          serverMessage ?? 'An unexpected error occurred. Please try again.',
        );
    }
  }

  /// Extracts the `message` field from a JSON error response body.
  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return null;
  }

  /// Extracts lock duration seconds from a 429 response body, if present.
  int? _extractLockDuration(dynamic data) {
    if (data is Map<String, dynamic>) {
      final duration = data['lockDurationSeconds'] ?? data['retryAfter'];
      if (duration is int) return duration;
      if (duration is String) return int.tryParse(duration);
    }
    // Default lock duration is 15 minutes.
    return 15 * 60;
  }
}

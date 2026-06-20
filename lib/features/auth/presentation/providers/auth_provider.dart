import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../qr_scanner/data/datasources/qr_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

/// Sealed state class for the auth feature.
sealed class AuthState {
  const AuthState();
}

/// No authenticated user — initial and post-logout state.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An async operation (sendOtp / verifyOtp / logout) is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User has successfully authenticated.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user, {this.pendingGalleryId});
  final AuthUser user;

  /// Non-null when the user authenticated via a pending QR link.
  /// The OTP screen uses this to navigate to the correct gallery.
  final String? pendingGalleryId;
}

/// An error occurred during an auth operation.
class AuthError extends AuthState {
  const AuthError({
    required this.message,
    this.isLocked = false,
    this.lockDurationSeconds,
  });

  final String message;

  /// True when the account is locked after 5 failed OTP attempts (HTTP 429).
  final bool isLocked;

  /// Lock duration in seconds; non-null when [isLocked] is true.
  final int? lockDurationSeconds;
}

// ---------------------------------------------------------------------------
// Dependency providers
// ---------------------------------------------------------------------------

/// Provides the [AuthRemoteDataSource] implementation.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSourceImpl(dio);
});

/// Provides the [AuthRepository] implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final storage = ref.watch(hiveStorageProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storage: storage,
  );
});

/// Provides the [SendOtpUseCase].
final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

/// Provides the [VerifyOtpUseCase].
final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

/// Provides the [LogoutUseCase].
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

/// Manages the auth state via Riverpod [StateNotifier].
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required SendOtpUseCase sendOtpUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required LogoutUseCase logoutUseCase,
    required AuthRepository repository,
    required HiveStorage storage,
    required Dio dio,
  })  : _sendOtp = sendOtpUseCase,
        _verifyOtp = verifyOtpUseCase,
        _logout = logoutUseCase,
        _repository = repository,
        _storage = storage,
        _dio = dio,
        super(const AuthUnauthenticated()) {
    _tryAutoLogin();
  }

  final SendOtpUseCase _sendOtp;
  final VerifyOtpUseCase _verifyOtp;
  final LogoutUseCase _logout;
  final AuthRepository _repository;
  final HiveStorage _storage;
  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Sends an OTP to [phone] for [userType] (`'studio_owner'` | `'customer'`).
  ///
  /// Returns `true` on success (caller should navigate to OTP screen).
  /// On failure transitions to [AuthError] and returns `false`.
  Future<bool> sendOtp({
    required String phone,
    required String userType,
  }) async {
    state = const AuthLoading();
    try {
      await _sendOtp(phone: phone, userType: userType);
      state = const AuthUnauthenticated();
      return true;
    } on AuthException catch (e) {
      state = AuthError(
        message: e.message,
        isLocked: e.isLocked,
        lockDurationSeconds: e.lockDurationSeconds,
      );
      return false;
    } catch (_) {
      state = const AuthError(message: 'Failed to send OTP. Please try again.');
      return false;
    }
  }

  /// Verifies the Firebase [idToken] or dev [otp] for [phone] + [userType] with the backend.
  ///
  /// On success: stores tokens, transitions to [AuthAuthenticated] (with an
  /// optional [AuthAuthenticated.pendingGalleryId] when a pending QR token
  /// exists), then attempts FCM token registration in the background.
  /// On failure: transitions to [AuthError] and returns `false`.
  Future<bool> verifyOtp({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _verifyOtp(
        phone: phone,
        idToken: idToken,
        otp: otp,
        userType: userType,
      );

      // Check for a pending QR token and validate it before transitioning.
      final pendingGalleryId = await _consumePendingQrToken();

      state = AuthAuthenticated(user, pendingGalleryId: pendingGalleryId);

      // Register FCM token in the background — non-blocking.
      _tryRegisterFcmToken();

      return true;
    } on AuthException catch (e) {
      state = AuthError(
        message: e.message,
        isLocked: e.isLocked,
        lockDurationSeconds: e.lockDurationSeconds,
      );
      return false;
    } catch (_) {
      state = const AuthError(
        message: 'Failed to verify OTP. Please try again.',
      );
      return false;
    }
  }

  /// Revokes the refresh token on the server and clears local credentials.
  ///
  /// Always transitions to [AuthUnauthenticated] (tokens are cleared locally
  /// regardless of server response).
  Future<void> logout({required String refreshToken}) async {
    state = const AuthUnauthenticated();
    // Execute the logout in the background (fire-and-forget) so the UI redirects instantly.
    // The repository's logout method will clear the tokens synchronously on start.
    _logout(refreshToken: refreshToken).catchError((_) {});
  }

  /// Helper that automatically retrieves the current refresh token and triggers a logout.
  Future<void> logoutCurrentUser() async {
    final token = _storage.getRefreshToken() ?? '';
    await logout(refreshToken: token);
  }

  /// Updates the user's profile details.
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  }) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return false;

    try {
      final updatedUser = await _repository.updateProfile(
        name: name,
        email: email,
        profilePhoto: profilePhoto,
        studioName: studioName,
        location: location,
        description: description,
      );
      state = AuthAuthenticated(
        updatedUser,
        pendingGalleryId: currentState.pendingGalleryId,
      );
      return true;
    } on AuthException catch (e) {
      state = AuthError(message: e.message);
      Future.delayed(const Duration(seconds: 2), () {
        if (state is AuthError) {
          state = currentState;
        }
      });
      return false;
    } catch (_) {
      state = const AuthError(message: 'Failed to update profile. Please try again.');
      Future.delayed(const Duration(seconds: 2), () {
        if (state is AuthError) {
          state = currentState;
        }
      });
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FCM token registration (best-effort, non-blocking)
  // ---------------------------------------------------------------------------

  /// Requests notification permission (on first launch) via
  /// [NotificationService], retrieves the FCM token, and registers it with
  /// the backend.
  ///
  /// This is called after a successful OTP verification.  It is intentionally
  /// non-blocking and swallows all errors so that auth flow is never blocked
  /// by a notification failure.
  Future<void> _tryRegisterFcmToken() async {
    // FCM is not available on web — skip silently.
    if (kIsWeb) return;
    try {
      final fcmToken =
          await NotificationService.requestPermissionAndGetToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      await _repository.registerFcmToken(token: fcmToken, platform: platform);
    } catch (_) {
      // Non-fatal — silently ignore FCM registration errors.
    }
  }

  /// Attempts to automatically restore authenticated state from a stored JWT token.
  void _tryAutoLogin() {
    try {
      final token = _storage.getAccessToken();
      if (token == null || token.isEmpty) return;

      final parts = token.split('.');
      if (parts.length != 3) return;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(resp) as Map<String, dynamic>;

      final sub = data['sub'] as String?;
      final role = data['role'] as String?;
      final galleryIds = List<String>.from(data['galleryIds'] ?? const <String>[]);

      if (sub != null && role != null) {
        final profile = _storage.getProfile();
        final name = profile['name'] ?? (role == 'studio_owner' ? 'Studio Owner' : 'Customer');
        final email = profile['email'];
        final profilePhoto = profile['profilePhoto'];

        final user = AuthUser(
          id: sub,
          name: name,
          email: email,
          profilePhoto: profilePhoto,
          role: role,
          galleryIds: galleryIds,
        );
        state = AuthAuthenticated(user);
      }
    } catch (_) {
      // Ignore token parsing/decoding failures.
    }
  }

  // ---------------------------------------------------------------------------
  // Pending QR token handling (best-effort)
  // ---------------------------------------------------------------------------

  /// Reads the pending QR token from storage, validates it with the backend,
  /// clears the token regardless of the result, and returns the gallery ID on
  /// success or `null` on any error.
  Future<String?> _consumePendingQrToken() async {
    final pendingToken = _storage.getPendingQrToken();
    if (pendingToken == null || pendingToken.isEmpty) return null;

    try {
      // Use a fresh Dio instance (auth interceptor not needed for this call).
      final qrDataSource = QrRemoteDataSourceImpl(_dio);
      final result = await qrDataSource.validateToken(pendingToken);
      return result.galleryId;
    } catch (_) {
      // Non-fatal — ignore QR validation failures.
      return null;
    } finally {
      // Always clear the pending token regardless of validation outcome.
      await _storage.clearPendingQrToken();
    }
  }
}

// ---------------------------------------------------------------------------
// AuthNotifier provider
// ---------------------------------------------------------------------------

/// Riverpod provider for [AuthNotifier].
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    sendOtpUseCase: ref.watch(sendOtpUseCaseProvider),
    verifyOtpUseCase: ref.watch(verifyOtpUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    repository: ref.watch(authRepositoryProvider),
    storage: ref.watch(hiveStorageProvider),
    dio: ref.watch(dioProvider),
  );
});

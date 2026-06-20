import '../entities/auth_user.dart';

/// Abstract contract for the auth feature's data operations.
///
/// Implementations live in the data layer.
abstract class AuthRepository {
  /// Sends an OTP to [phone] for the given [userType]
  /// (`'studio_owner'` or `'customer'`).
  ///
  /// Returns a success message on success.
  /// Throws [AuthException] on failure.
  Future<String> sendOtp({
    required String phone,
    required String userType,
  });

  /// Verifies the Firebase [idToken] or dev [otp] for [phone] + [userType].
  ///
  /// Returns an [AuthUser] and stores the tokens on success.
  /// Throws [AuthException] on failure.
  Future<AuthUser> verifyOtp({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  });

  /// Exchanges [refreshToken] for a new access + refresh token pair.
  ///
  /// Throws [AuthException] on failure.
  Future<void> refreshTokens({required String refreshToken});

  /// Revokes [refreshToken] and clears local tokens.
  ///
  /// Throws [AuthException] on failure.
  Future<void> logout({required String refreshToken});

  /// Registers the device FCM [token] for push notifications.
  ///
  /// [platform] is either `'android'` or `'ios'`.
  /// Throws [AuthException] on failure.
  Future<void> registerFcmToken({
    required String token,
    required String platform,
  });

  /// Retrieves the current user's profile details.
  Future<AuthUser> getProfile();

  /// Updates the current user's profile details.
  Future<AuthUser> updateProfile({
    String? name,
    String? email,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  });
}

// ---------------------------------------------------------------------------
// Domain-level exception
// ---------------------------------------------------------------------------

/// Thrown by [AuthRepository] implementations to surface auth-specific errors.
class AuthException implements Exception {
  const AuthException(this.message, {this.isLocked = false, this.lockDurationSeconds});

  final String message;

  /// True when the account has been locked after too many failed attempts.
  final bool isLocked;

  /// How long (in seconds) the lock lasts; non-null when [isLocked] is true.
  final int? lockDurationSeconds;

  @override
  String toString() => 'AuthException: $message';
}

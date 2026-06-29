import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Verifies the OTP and retrieves the authenticated user.
class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  /// Calls [AuthRepository.verifyOtp] with [phone], [idToken]/[otp], and [userType].
  ///
  /// Returns an [AuthUser] on success.
  Future<AuthUser> call({
    required String phone,
    required String userType,
    String? idToken,
    String? otp,
  }) {
    return _repository.verifyOtp(
      phone: phone,
      idToken: idToken,
      otp: otp,
      userType: userType,
    );
  }
}

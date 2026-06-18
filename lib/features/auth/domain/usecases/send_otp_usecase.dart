import '../repositories/auth_repository.dart';

/// Sends an OTP to the given phone number.
class SendOtpUseCase {
  const SendOtpUseCase(this._repository);

  final AuthRepository _repository;

  /// Calls [AuthRepository.sendOtp] with [phone] and [userType].
  ///
  /// Returns the success message from the backend.
  Future<String> call({
    required String phone,
    required String userType,
  }) {
    return _repository.sendOtp(phone: phone, userType: userType);
  }
}

import '../repositories/auth_repository.dart';

/// Revokes the refresh token and clears local credentials.
class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  /// Calls [AuthRepository.logout] with [refreshToken].
  Future<void> call({required String refreshToken}) {
    return _repository.logout(refreshToken: refreshToken);
  }
}

import '../repositories/auth_repository.dart';

/// Refreshes the access and refresh tokens using an existing refresh token.
class RefreshTokenUseCase {
  const RefreshTokenUseCase(this._repository);

  final AuthRepository _repository;

  /// Calls [AuthRepository.refreshTokens] with [refreshToken].
  Future<void> call({required String refreshToken}) {
    return _repository.refreshTokens(refreshToken: refreshToken);
  }
}

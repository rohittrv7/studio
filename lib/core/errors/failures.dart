/// Typed domain failure hierarchy for the Studio Gallery app.
///
/// All network and data-layer errors are mapped to one of these sealed
/// subtypes before bubbling up to the presentation layer.  This keeps UI
/// code free of raw [DioException] / platform exceptions.
sealed class Failure {
  const Failure();
}

// ---------------------------------------------------------------------------
// Network-level failures
// ---------------------------------------------------------------------------

/// No internet connection, DNS failure, or connection/receive/send timeout.
class NetworkFailure extends Failure {
  const NetworkFailure();

  @override
  String toString() => 'NetworkFailure: No internet connection';
}

// ---------------------------------------------------------------------------
// HTTP response failures
// ---------------------------------------------------------------------------

/// Server returned HTTP 400 — the request body failed basic validation.
class BadRequestFailure extends Failure {
  const BadRequestFailure([this.message = 'Bad request']);

  final String message;

  @override
  String toString() => 'BadRequestFailure: $message';
}

/// Server returned HTTP 401 — the user is not (or is no longer) authenticated.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();

  @override
  String toString() => 'UnauthorizedFailure: Authentication required';
}

/// Server returned HTTP 403 — the user is authenticated but lacks permission.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure();

  @override
  String toString() => 'ForbiddenFailure: Access denied';
}

/// Server returned HTTP 404 — the requested resource does not exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure();

  @override
  String toString() => 'NotFoundFailure: Resource not found';
}

/// Server returned HTTP 409 — the request conflicts with existing state
/// (e.g. duplicate phone number).
class ConflictFailure extends Failure {
  const ConflictFailure([this.message = 'Conflict']);

  final String message;

  @override
  String toString() => 'ConflictFailure: $message';
}

/// Server returned HTTP 413 — the uploaded file exceeds the size limit.
class PayloadTooLargeFailure extends Failure {
  const PayloadTooLargeFailure();

  @override
  String toString() => 'PayloadTooLargeFailure: File exceeds the size limit';
}

/// Server returned HTTP 415 — the media type of the upload is not supported.
class UnsupportedMediaTypeFailure extends Failure {
  const UnsupportedMediaTypeFailure();

  @override
  String toString() => 'UnsupportedMediaTypeFailure: Unsupported media type';
}

/// Server returned HTTP 422 — the request body passed structural validation
/// but is semantically unprocessable (e.g. folder depth exceeded).
class UnprocessableEntityFailure extends Failure {
  const UnprocessableEntityFailure([this.message = 'Unprocessable entity']);

  final String message;

  @override
  String toString() => 'UnprocessableEntityFailure: $message';
}

/// Server returned HTTP 429 — the client has exceeded the rate limit.
class RateLimitedFailure extends Failure {
  const RateLimitedFailure();

  @override
  String toString() => 'RateLimitedFailure: Too many requests';
}

/// Server returned an HTTP 5xx status — an internal server error occurred.
class ServerFailure extends Failure {
  const ServerFailure(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ServerFailure($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Legacy alias — kept so older call sites that typed values as
// [ValidationFailure] continue to compile without modification.
// ---------------------------------------------------------------------------

/// Alias for [BadRequestFailure] / [UnprocessableEntityFailure].
///
/// Prefer the more specific types for new code.
@Deprecated('Use BadRequestFailure or UnprocessableEntityFailure instead')
typedef ValidationFailure = BadRequestFailure;

// ---------------------------------------------------------------------------
// Catch-all
// ---------------------------------------------------------------------------

/// Catch-all for unexpected / unclassified errors.
class UnknownFailure extends Failure {
  const UnknownFailure(this.message);

  final String message;

  @override
  String toString() => 'UnknownFailure: $message';
}

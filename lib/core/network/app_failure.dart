// Backward-compatibility re-export.
//
// The canonical failure hierarchy now lives in
// `lib/core/errors/failures.dart`.  This file re-exports all types from
// there so that existing import paths continue to work without modification.
//
// New code should import `package:mobile/core/errors/failures.dart` directly.
import '../errors/failures.dart';
export '../errors/failures.dart';

/// Type alias kept for backward compatibility.
///
/// All subtypes extend [Failure]; callers that previously typed values as
/// [AppFailure] can switch to [Failure] at their own pace.
typedef AppFailure = Failure;

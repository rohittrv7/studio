import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hive_storage.dart';

// Conditional import:
//  - On web:    web_storage_web.dart  (uses dart:html localStorage)
//  - On mobile: web_storage.dart      (stub — never actually called on mobile)
import 'web_storage.dart'
    if (dart.library.html) 'web_storage_web.dart';

/// Provides the correct [HiveStorage] implementation for the current platform.
///
/// - **Mobile**: uses [HiveStorageImpl] backed by encrypted Hive boxes.
/// - **Web**: uses [WebStorage] backed by browser localStorage so tokens
///   persist across page reloads without needing Hive.
final hiveStorageProvider = Provider<HiveStorage>(
  (_) => kIsWeb ? WebStorage.instance : HiveStorage.instance,
);

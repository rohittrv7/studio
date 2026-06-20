// ignore_for_file: avoid_web_libraries_in_flutter
/// Web localStorage-backed implementation of [HiveStorage].
///
/// This file imports dart:html which is only available on web.
/// It is selected via conditional import in storage_providers.dart:
///   import 'web_storage.dart'
///       if (dart.library.html) 'web_storage_web.dart';
///
/// This version is the STUB used on non-web platforms (VM/mobile/desktop).
/// The real implementation is in web_storage_web.dart.
library web_storage;

import 'package:hive/hive.dart';
import 'hive_storage.dart';

/// Non-web stub — never actually called at runtime on mobile/desktop
/// because [storage_providers.dart] only uses it when [kIsWeb] is true.
class WebStorage implements HiveStorage {
  const WebStorage._();
  static const WebStorage instance = WebStorage._();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  String? getAccessToken() => null;

  @override
  String? getRefreshToken() => null;

  @override
  Future<void> clearTokens() async {}

  @override
  Future<void> saveProfile({
    required String name,
    String? email,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  }) async {}

  @override
  Map<String, String?> getProfile() => {};

  @override
  Future<void> savePendingQrToken(String token) async {}

  @override
  String? getPendingQrToken() => null;

  @override
  Future<void> clearPendingQrToken() async {}

  @override
  Box<dynamic> get galleryBox => throw UnsupportedError('web only');

  @override
  Box<dynamic> get folderBox => throw UnsupportedError('web only');

  @override
  Box<dynamic> get mediaBox => throw UnsupportedError('web only');
}

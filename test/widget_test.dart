// Smoke test for StudioGalleryApp.
//
// Verifies that the app widget tree builds without throwing when Hive storage
// is stubbed (Hive boxes cannot be opened in unit/widget test environments
// since Hive.initFlutter() requires a real file-system path).
//
// Firebase and Hive are NOT initialised here — instead the providers that
// depend on them are overridden with lightweight fakes so the test stays fast
// and hermetic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mobile/core/storage/hive_storage.dart';
import 'package:mobile/core/storage/storage_providers.dart';
import 'package:mobile/main.dart';

// ---------------------------------------------------------------------------
// Fake HiveStorage
// ---------------------------------------------------------------------------

/// A fake [HiveStorage] implementation that returns safe defaults without
/// requiring any Hive box to be opened on disk.
class _FakeHiveStorage implements HiveStorage {
  @override
  String? getAccessToken() => null; // unauthenticated → router redirects to /login

  @override
  String? getRefreshToken() => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clearTokens() async {}

  @override
  Future<void> saveProfile({
    required String name,
    String? email,
    String? profilePhoto,
  }) async {}

  @override
  Map<String, String?> getProfile() => {
        'name': null,
        'email': null,
        'profilePhoto': null,
      };

  @override
  Future<void> savePendingQrToken(String token) async {}

  @override
  String? getPendingQrToken() => null;

  @override
  Future<void> clearPendingQrToken() async {}

  @override
  Box<dynamic> get galleryBox => throw UnimplementedError('galleryBox');

  @override
  Box<dynamic> get folderBox => throw UnimplementedError('folderBox');

  @override
  Box<dynamic> get mediaBox => throw UnimplementedError('mediaBox');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'StudioGalleryApp smoke test — widget tree builds without error',
    (WidgetTester tester) async {
      // Override hiveStorageProvider so no real Hive box is needed.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveStorageProvider.overrideWithValue(_FakeHiveStorage()),
          ],
          child: const StudioGalleryApp(),
        ),
      );

      // Give the router one frame to resolve the redirect to /login.
      await tester.pump();

      // No exception should have been thrown.
      expect(tester.takeException(), isNull);

      // Pump to let the 2.5s splash screen timer fire and complete.
      await tester.pump(const Duration(seconds: 3));

      // Dispose the app widget tree so that periodic timers are cancelled.
      await tester.pumpWidget(const SizedBox());
    },
  );
}

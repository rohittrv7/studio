import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

/// Abstract interface for local storage used throughout the app.
///
/// Having a dedicated interface allows tests to substitute lightweight fakes
/// without requiring a real Hive file-system path.
///
/// Production code uses [HiveStorageImpl] via [HiveStorage.instance].
/// In tests, override [hiveStorageProvider] with a custom [HiveStorage]
/// implementation.
abstract class HiveStorage {
  // ---------------------------------------------------------------------------
  // Auth token helpers
  // ---------------------------------------------------------------------------

  /// Persists access and refresh tokens.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Returns the stored access token, or null if not present.
  String? getAccessToken();

  /// Returns the stored refresh token, or null if not present.
  String? getRefreshToken();

  /// Persists user profile information.
  Future<void> saveProfile({
    required String name,
    String? email,
    String? phone,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  });

  /// Returns user profile information.
  Map<String, String?> getProfile();

  /// Removes all auth-related data.
  Future<void> clearTokens();

  // ---------------------------------------------------------------------------
  // Pending QR token helpers
  // ---------------------------------------------------------------------------

  /// Persists a pending QR token so the app can navigate to the gallery after
  /// the user completes the login flow.
  Future<void> savePendingQrToken(String token);

  /// Returns the stored pending QR token, or null if none is stored.
  String? getPendingQrToken();

  /// Removes the pending QR token.
  Future<void> clearPendingQrToken();

  // ---------------------------------------------------------------------------
  // Box accessors
  // ---------------------------------------------------------------------------

  /// Returns the opened gallery cache box.
  Box<dynamic> get galleryBox;

  /// Returns the opened folder cache box.
  Box<dynamic> get folderBox;

  /// Returns the opened media cache box.
  Box<dynamic> get mediaBox;

  // ---------------------------------------------------------------------------
  // Singleton accessor
  // ---------------------------------------------------------------------------

  /// Shared singleton used for dependency injection.
  ///
  /// All callers should prefer receiving [HiveStorage] via Riverpod's
  /// [hiveStorageProvider] so that tests can substitute a fake implementation.
  static HiveStorage get instance => HiveStorageImpl.instance;

  /// Opens all Hive boxes.  Must be called once after [Hive.initFlutter()].
  static Future<void> init() => HiveStorageImpl._init();
}

// ---------------------------------------------------------------------------
// HiveStorageImpl — production implementation
// ---------------------------------------------------------------------------

/// Concrete [HiveStorage] backed by Hive boxes on the file system.
class HiveStorageImpl implements HiveStorage {
  /// Private constructor — use [HiveStorageImpl.instance].
  const HiveStorageImpl._();

  /// Shared instance used for dependency injection.
  static const HiveStorageImpl instance = HiveStorageImpl._();

  // ---------------------------------------------------------------------------
  // Box names
  // ---------------------------------------------------------------------------
  static const String _keysBoxName = 'keysBox';
  static const String _authBoxName = 'authBox';
  static const String _galleryBoxName = 'galleryBox';
  static const String _folderBoxName = 'folderBox';
  static const String _mediaBoxName = 'mediaBox';

  // Key names inside authBox
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _pendingQrTokenKey = 'pendingQrToken';
  static const String _userNameKey = 'userName';
  static const String _userEmailKey = 'userEmail';
  static const String _userPhoneKey = 'userPhone';
  static const String _userProfilePhotoKey = 'userProfilePhoto';
  static const String _studioNameKey = 'studioName';
  static const String _locationKey = 'location';
  static const String _descriptionKey = 'description';

  // Key name for the encryption key stored in keysBox
  static const String _encryptionKeyName = 'hiveEncryptionKey';

  // ---------------------------------------------------------------------------
  // Opened box references (populated by [_init])
  // ---------------------------------------------------------------------------
  static late Box<dynamic> _authBox;
  static late Box<dynamic> _galleryBox;
  static late Box<dynamic> _folderBox;
  static late Box<dynamic> _mediaBox;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Opens all Hive boxes.  Must be called after [Hive.initFlutter()].
  static Future<void> _init() async {
    // 1. Open the unencrypted keys box to store/retrieve the encryption key.
    final keysBox = await Hive.openBox<dynamic>(_keysBoxName);

    // 2. Retrieve or generate the AES encryption key for authBox.
    Uint8List encryptionKey;
    final storedKey = keysBox.get(_encryptionKeyName);
    if (storedKey == null) {
      encryptionKey = Uint8List.fromList(Hive.generateSecureKey());
      await keysBox.put(_encryptionKeyName, encryptionKey);
    } else {
      encryptionKey = Uint8List.fromList((storedKey as List).cast<int>());
    }

    // 3. Open the encrypted authBox for token storage.
    _authBox = await Hive.openBox<dynamic>(
      _authBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    // 4. Open plain boxes for cached gallery/folder/media data.
    _galleryBox = await Hive.openBox<dynamic>(_galleryBoxName);
    _folderBox = await Hive.openBox<dynamic>(_folderBoxName);
    _mediaBox = await Hive.openBox<dynamic>(_mediaBoxName);
  }

  // ---------------------------------------------------------------------------
  // Auth token helpers
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _authBox.put(_accessTokenKey, accessToken);
    await _authBox.put(_refreshTokenKey, refreshToken);
  }

  @override
  String? getAccessToken() {
    return _authBox.get(_accessTokenKey) as String?;
  }

  @override
  String? getRefreshToken() {
    return _authBox.get(_refreshTokenKey) as String?;
  }

  @override
  Future<void> clearTokens() async {
    await _authBox.delete(_accessTokenKey);
    await _authBox.delete(_refreshTokenKey);
    await _authBox.delete(_userNameKey);
    await _authBox.delete(_userEmailKey);
    await _authBox.delete(_userPhoneKey);
    await _authBox.delete(_userProfilePhotoKey);
    await _authBox.delete(_studioNameKey);
    await _authBox.delete(_locationKey);
    await _authBox.delete(_descriptionKey);
  }

  @override
  Future<void> saveProfile({
    required String name,
    String? email,
    String? phone,
    String? profilePhoto,
    String? studioName,
    String? location,
    String? description,
  }) async {
    await _authBox.put(_userNameKey, name);
    await _authBox.put(_userEmailKey, email);
    await _authBox.put(_userPhoneKey, phone);
    await _authBox.put(_userProfilePhotoKey, profilePhoto);
    await _authBox.put(_studioNameKey, studioName);
    await _authBox.put(_locationKey, location);
    await _authBox.put(_descriptionKey, description);
  }

  @override
  Map<String, String?> getProfile() {
    return {
      'name': _authBox.get(_userNameKey) as String?,
      'email': _authBox.get(_userEmailKey) as String?,
      'phone': _authBox.get(_userPhoneKey) as String?,
      'profilePhoto': _authBox.get(_userProfilePhotoKey) as String?,
      'studioName': _authBox.get(_studioNameKey) as String?,
      'location': _authBox.get(_locationKey) as String?,
      'description': _authBox.get(_descriptionKey) as String?,
    };
  }

  // ---------------------------------------------------------------------------
  // Pending QR token helpers
  // ---------------------------------------------------------------------------

  @override
  Future<void> savePendingQrToken(String token) async {
    await _authBox.put(_pendingQrTokenKey, token);
  }

  @override
  String? getPendingQrToken() {
    return _authBox.get(_pendingQrTokenKey) as String?;
  }

  @override
  Future<void> clearPendingQrToken() async {
    await _authBox.delete(_pendingQrTokenKey);
  }

  // ---------------------------------------------------------------------------
  // Box accessors
  // ---------------------------------------------------------------------------

  @override
  Box<dynamic> get galleryBox => _galleryBox;

  @override
  Box<dynamic> get folderBox => _folderBox;

  @override
  Box<dynamic> get mediaBox => _mediaBox;
}

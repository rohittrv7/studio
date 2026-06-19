import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL constants for the Studio Gallery backend.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://YOUR-NGROK-URL.ngrok-free.app
///
/// Or for local Wi-Fi device testing:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
class ApiConstants {
  ApiConstants._();

  /// Set via `--dart-define=API_BASE_URL=...` (highest priority).
  /// Example ngrok: `https://abc123.ngrok-free.app`
  /// Example LAN:   `http://192.168.1.5:3000`
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://studio-backend-5slu.onrender.com',
  );

  /// Your computer's local IP address on the Wi-Fi network.
  static const String _physicalDeviceIp = '10.158.52.14';

  /// Set to `true` when running on a real Android/iOS device (not emulator).
  static const bool usePhysicalDevice = true;

  static const int _backendPort = 3000;

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      final trimmed = _overrideBaseUrl.replaceAll(RegExp(r'/+$'), '');
      return trimmed.endsWith('/api/v1') ? trimmed : '$trimmed/api/v1';
    }
    if (kIsWeb) {
      return 'http://localhost:$_backendPort/api/v1';
    }
    if (usePhysicalDevice) {
      return 'http://$_physicalDeviceIp:$_backendPort/api/v1';
    }
    // Connect to host PC over local Wi-Fi network (or via adb reverse for USB debugging)
    return 'http://127.0.0.1:$_backendPort/api/v1';
  }

  // ── Auth endpoints ─────────────────────────────────────────────────────────
  static const String refreshToken = '/auth/refresh';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String logout = '/auth/logout';
  static const String registerFcmToken = '/auth/register-fcm-token';

  // ── Gallery endpoints ──────────────────────────────────────────────────────
  static const String galleries = '/galleries';
  static String gallery(String id) => '/galleries/$id';
  static String galleryFolders(String id) => '/galleries/$id/folders';
  static String assignGallery(String id) => '/galleries/$id/assign';

  // ── Customer endpoints ─────────────────────────────────────────────────────
  static const String customers = '/customers';

  // ── Media endpoints ────────────────────────────────────────────────────────
  static String galleryMedia(String galleryId) =>
      '/galleries/$galleryId/media';
  static String galleryMediaFile(String galleryId, String mediaId) =>
      '/galleries/$galleryId/media/$mediaId';

  // ── QR endpoints ───────────────────────────────────────────────────────────
  static String qrValidate(String token) => '/qr/validate/$token';
  static String qrGenerate(String galleryId) => '/qr/generate/$galleryId';

  // ── Analytics endpoints ────────────────────────────────────────────────────
  static const String analyticsView = '/analytics/view';

  // ── Favorites endpoints ────────────────────────────────────────────────────
  static const String favorites = '/favorites';
  static String favoriteDelete(String mediaFileId) => '/favorites/$mediaFileId';
}

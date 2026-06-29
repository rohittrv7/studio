import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecurityUtil {
  static const MethodChannel _channel = MethodChannel('com.studiogallery.app/security');
  static int _secureCount = 0;

  /// Toggles screenshot blocking dynamically.
  static Future<void> setSecure(bool secure) async {
    if (secure) {
      _secureCount++;
    } else {
      _secureCount--;
      if (_secureCount < 0) _secureCount = 0;
    }

    try {
      if (_secureCount > 0) {
        await _channel.invokeMethod('enableSecure');
      } else {
        await _channel.invokeMethod('disableSecure');
      }
    } on PlatformException catch (e) {
      // Fallback silently if platform not supported
      debugPrint('SecurityUtil platform method channel error: ${e.message}');
    }
  }
}

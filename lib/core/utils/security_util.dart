import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecurityUtil {
  static const MethodChannel _channel = MethodChannel('com.studiogallery.app/security');

  /// Toggles screenshot blocking dynamically.
  static Future<void> setSecure(bool secure) async {
    try {
      if (secure) {
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

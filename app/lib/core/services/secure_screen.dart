import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The screenshot shield, driven from Dart.
///
/// On Android this toggles `FLAG_SECURE` on the window, which is the SYSTEM's
/// own block: the window is left out of screenshots and screen recordings, and
/// recent Androids also blank its preview in the app switcher. That matters —
/// a "protection" drawn only by the UI would be trivially bypassed.
///
/// Every call is best-effort: on a platform without the channel (iOS, desktop,
/// tests) it silently does nothing, so callers never have to branch.
class SecureScreen {
  SecureScreen._();

  static const MethodChannel _channel =
      MethodChannel('yazzoki.secure/screen');

  /// Whether the shield is currently on (mirrors the native flag).
  static bool get isEnabled => _enabled;
  static bool _enabled = false;

  /// Raises the shield. Idempotent.
  static Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    await _invoke('enable');
  }

  /// Drops the shield. Idempotent, and safe to call when it was never raised
  /// (leaving a view-once must always be able to clear it).
  static Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    await _invoke('disable');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // No native side (tests / other platforms): nothing to shield.
    } catch (e) {
      if (kDebugMode) debugPrint('SecureScreen.$method falhou: $e');
    }
  }
}

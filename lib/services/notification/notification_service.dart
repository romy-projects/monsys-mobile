import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';

/// Background push handler — MUST be a top-level function so FCM can spawn the
/// background isolate entry point.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured yet — nothing to do in the background isolate.
  }
  debugPrint('FCM background message: ${message.messageId}');
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

/// FCM push notification support (panelx device-token registration).
///
/// Designed to be SAFE BEFORE FIREBASE IS CONFIGURED: every Firebase call is
/// guarded, so the app builds and runs normally today and simply no-ops.
/// Once the Firebase config files are added (TASKLIST.md → M-11 activation
/// steps), token registration happens automatically on login and app start.
class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  bool _attempted = false;
  String? _fcmToken;

  /// Idempotent. Initializes Firebase (when available), requests notification
  /// permission, registers the FCM token with the backend, and wires up the
  /// message listeners. Returns true only when push is fully active.
  Future<bool> initializeAndRegister() async {
    if (_attempted) return _fcmToken != null;
    _attempted = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // System permission prompt (iOS always; Android 13+ POST_NOTIFICATIONS).
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmToken = await FirebaseMessaging.instance.getToken();
      await _registerToken(_fcmToken);

      // FCM can rotate tokens — re-register on refresh.
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _registerToken(token);
      });

      // Foreground: message arrived while the app is open.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            'FCM foreground: ${message.notification?.title ?? message.data}');
      });

      // Background: user tapped a notification and the app resumed.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM opened app: ${message.data}');
      });

      // Terminated: app was cold-started by tapping a notification.
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM cold start: ${initialMessage.data}');
      }

      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      debugPrint('FCM push notifications active.');
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('FCM unavailable (Firebase plugin not set up yet): $e');
      return false;
    } on FirebaseException catch (e) {
      debugPrint(
          'FCM unavailable (Firebase not configured: ${e.code}). '
          'Add google-services.json / GoogleService-Info.plist to activate.');
      return false;
    } catch (e) {
      debugPrint('FCM setup skipped: $e');
      return false;
    }
  }

  /// Registers the token with panelx (POST /device/token). The API requires
  /// `fcm_token` + `platform` (android|ios); other targets are skipped since
  /// push delivery is mobile-only. Failures never break the app.
  Future<void> _registerToken(String? token) async {
    if (token == null) return;
    String platform;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        platform = 'android';
        break;
      case TargetPlatform.iOS:
        platform = 'ios';
        break;
      default:
        debugPrint('FCM registration skipped: unsupported platform');
        return;
    }
    try {
      await _ref.read(apiServiceProvider).post(
            ApiConstants.deviceToken,
            data: {'fcm_token': token, 'platform': platform},
          );
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Tells panelx to drop this device's token (POST /device/revoke).
  /// Best-effort — always safe to call.
  Future<void> revokeDevice() async {
    _fcmToken = null;
    try {
      await _ref.read(apiServiceProvider).post(ApiConstants.deviceRevoke);
    } catch (e) {
      debugPrint('FCM token revoke failed: $e');
    }
  }
}
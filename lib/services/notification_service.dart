import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Runs in the background isolate when a push arrives while the app is closed.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

/// Wraps Firebase Messaging + local notifications.
class NotificationService {
  NotificationService._();

  static const _channelId = 'harakatlan_attack';
  static const _channelName = 'Hujum xabarlari';
  static const _channelDesc = "Qal'angizga hujum bo'lganda bildirishnomalar";

  static final _fln = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Must be called once, before [FirebaseMessaging] is used.
  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    _ready = true;

    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Android: high-importance channel
    if (!kIsWeb && Platform.isAndroid) {
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
          ));
    }

    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Show a local notification while the app is in the FOREGROUND
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _fln.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
  }

  /// Asks the OS for notification permission (iOS always, Android 13+).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Returns the FCM device token (null on web or if not granted).
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  /// Listens for token refresh and calls [onToken] with the new value.
  static void onTokenRefresh(void Function(String) onToken) {
    FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
  }
}

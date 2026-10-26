import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// defaultTargetPlatform instead of dart:io's Platform: main.dart imports this
// file unconditionally and only guards the *calls* with kIsWeb, but an import
// is resolved at compile time and dart:io does not exist on the web build.
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform, ValueNotifier, kIsWeb;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'notification_service.dart';

const _notificationChannel = AndroidNotificationChannel(
  // Android locks a channel's sound when it is created. A new ID ensures
  // members who already installed an older APK receive the custom tone too.
  'rmb_connect_alerts_v2',
  'RMB Connect notifications',
  description: 'Important updates from RMB Connect',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('volvo3'),
  enableVibration: true,
);



@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  try {
    await Firebase.initializeApp();

    final title =
        message.notification?.title ??
            message.data['title'] ??
            'New notification';

    final body = PushNotificationService._messageBody(message);

    // Always persist the incoming notification locally so it is visible
    // in the Notifications page even if backend database has not recorded it.
    await NotificationService.saveLocalNotification(
      title: title,
      message: body,
      type: message.data['type']?.toString() ?? 'push',
    );

    // Notification-payload messages are rendered by Android itself when the
    // app is backgrounded or closed. Showing them again here produced two
    // cards for a single referral. This handler is only needed for data-only
    // messages, which Android has no system UI for.
    if (message.notification != null) return;

    final localNotifications = FlutterLocalNotificationsPlugin();

    // A background isolate has no state from the foreground app. Initialising
    // the local-notifications plugin here makes data-only FCM messages render
    // reliably when the app is closed or backgrounded.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await localNotifications.initialize(settings: initSettings);

    final androidImplementation =
    localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >();

    await androidImplementation?.createNotificationChannel(
      _notificationChannel,
    );

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannel.id,
        _notificationChannel.name,
        channelDescription: _notificationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('volvo3'),
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        ticker: switch (message.data['type']?.toString().toLowerCase()) {
          'r2r' => 'R2R notification',
          'cnote' => 'C-Note notification',
          'testimonial' => 'Testimonial notification',
          'referral' => 'Referral notification',
          _ => 'RMB Connect notification',
        },
      ),
    );

    await localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: message.data.toString(),
    );
  } catch (e) {
    debugPrint('Background FCM notification failed: $e');
  }
}

class PushNotificationService {
  static const _fcmTokenPreferenceKey = 'fcm_token';

  /// The app shell listens to this so tapping a referral notification opens
  /// the correct received-referrals list instead of only writing to the log.
  static final ValueNotifier<Map<String, String>?> notificationTap =
      ValueNotifier(null);

  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    final fcmPermission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    final androidImplementation =
    _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Firebase's permission request covers iOS. Request Android 13+'s
    // POST_NOTIFICATIONS permission explicitly too, because the local plugin
    // is what displays foreground and data-only referral messages.
    final androidPermission =
        await androidImplementation?.requestNotificationsPermission();
    debugPrint(
      '[push] notification permission: '
      'FCM=${fcmPermission.authorizationStatus}, '
      'Android=$androidPermission',
    );

    await androidImplementation?.createNotificationChannel(
      _notificationChannel,
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) {
        _publishLocalNotificationTap(response.payload);
      },
    );

    FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        final title = message.notification?.title ?? message.data['title'] ?? '';
        final body = _messageBody(message);
        if (title.isNotEmpty || body.isNotEmpty) {
          NotificationService.saveLocalNotification(
            title: title,
            message: body,
            type: message.data['type']?.toString() ?? 'push',
          );
        }
        final tapData = Map<String, dynamic>.from(message.data);
        if (title.isNotEmpty) tapData['title'] = title;
        if (body.isNotEmpty) tapData['message'] = body;
        _publishNotificationTap(tapData);
      },
    );

    // A notification payload is rendered by Android while the app is closed.
    // Read the launch message too, so a notification tap from a terminated app is
    // handled by the same Flutter notification flow once the UI starts.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final title = initialMessage.notification?.title ?? initialMessage.data['title'] ?? '';
      final body = _messageBody(initialMessage);
      if (title.isNotEmpty || body.isNotEmpty) {
        NotificationService.saveLocalNotification(
          title: title,
          message: body,
          type: initialMessage.data['type']?.toString() ?? 'push',
        );
      }
      final tapData = Map<String, dynamic>.from(initialMessage.data);
      if (title.isNotEmpty) tapData['title'] = title;
      if (body.isNotEmpty) tapData['message'] = body;
      _publishNotificationTap(tapData);
    }

    await _registerToken(messaging);

    messaging.onTokenRefresh.listen((token) async {
      await _cacheToken(token);
      await _sendTokenToServer(token);
    });
  }

  /// A notification arriving while the app is open. Showing it in-app is the
  /// whole point of registering this listener - without it a referral that
  /// arrives while the member is looking at the app is silently dropped, and
  /// they only find out by opening the Referrals screen later.
  static Future<void> _showForegroundNotification(
      RemoteMessage message,
      ) async {
    debugPrint('[push] foreground message: ${message.data}');
    final title =
        message.notification?.title ??
            message.data['title'] ??
            'New notification';

    final body = _messageBody(message);

    if (title.isNotEmpty || body.isNotEmpty) {
      await NotificationService.saveLocalNotification(
        title: title,
        message: body,
        type: message.data['type']?.toString() ?? 'push',
      );
    }

    try {
      await _showLocalNotification(message);
    } catch (e) {
      debugPrint('[push] could not display foreground notification: $e');
    }
  }

  static String _messageBody(RemoteMessage message) {
    final notificationBody = message.notification?.body?.trim();
    if (notificationBody != null && notificationBody.isNotEmpty) {
      return notificationBody;
    }
    for (final key in [
      'body',
      'message',
      'notification_message',
      'notification_body',
      'message_body',
      'message_text',
      'description',
      'content',
      'details',
      'text',
      'msg',
      'alert',
      'note',
      'notes',
    ]) {
      final value = message.data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final title = message.notification?.title?.trim() ?? message.data['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    return '';
  }

  static Future<void> _showLocalNotification(
      RemoteMessage message,
      ) async {
    final title =
        message.notification?.title ??
            message.data['title'] ??
            'New notification';

    final body = _messageBody(message);

    if (body.isEmpty && title.isEmpty) {
      return;
    }

    final androidImplementation =
    _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >();

    await androidImplementation?.createNotificationChannel(
      _notificationChannel,
    );

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannel.id,
        _notificationChannel.name,
        channelDescription: _notificationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('volvo3'),
        enableVibration: true,
        visibility: NotificationVisibility.public,
        ticker: switch (message.data['type']?.toString().toLowerCase()) {
          'r2r' => 'R2R notification',
          'cnote' => 'C-Note notification',
          'testimonial' => 'Testimonial notification',
          'referral' => 'Referral notification',
          _ => 'RMB Connect notification',
        },
      ),
    );

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  static void _publishNotificationTap(Map<String, dynamic> data) {
    final payload = data.map((key, value) => MapEntry(key, value.toString()));
    debugPrint('[push] notification tapped: $payload');
    notificationTap.value = payload;
  }

  static void _publishLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _publishNotificationTap(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {
      // A notification from an older app version may contain a non-JSON
      // payload. It remains harmless; it simply has no destination route.
    }
    debugPrint('[push] notification tapped: $payload');
  }

  static Future<void> _registerToken(
      FirebaseMessaging messaging,
      ) async {
    final token = await messaging.getToken();

    if (token != null) {
      debugPrint('[push] FCM token: $token');
      await _cacheToken(token);
      await _sendTokenToServer(token);
    }
  }

  static Future<void> _cacheToken(String token) async {
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenPreferenceKey, token);
  }

  static Future<void> registerCurrentDevice() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      await _registerToken(
        FirebaseMessaging.instance,
      );
    } catch (e) {
      debugPrint('[push] current device token registration failed: $e');
    }
  }

  static Future<void> _sendTokenToServer(
      String token,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id') ?? '';

    if (userId.isEmpty) {
      debugPrint('[push] no signed-in user_id, token not registered');
      return;
    }

    try {
      final String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        platform = defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      }

      final tokenPayload = {
        'user_id': userId,
        'fcm_token': token,
        'platform': platform,
      };

      dynamic response;
      try {
        response = await ApiClient.post(
          'device_token.php',
          tokenPayload,
          baseOverride: ApiClient.flutterBaseUrl,
        );
      } catch (_) {
        response = await ApiClient.postFormData(
          'device_token.php',
          tokenPayload,
          baseOverride: ApiClient.flutterBaseUrl,
        );
      }

      if (response is! Map ||
          (response['status'] != true &&
              response['success'] != true &&
              response['token_registered'] != true)) {
        throw StateError('Device-token API did not confirm registration: $response');
      }
      debugPrint('[push] device token registered for user $userId ($platform): ${response['message']}');
    } catch (e) {
      // Previously swallowed with no log at all, so a token that never reached
      // the server looked identical to "no notifications configured".
      debugPrint('[push] device token registration failed: $e');
    }
  }
}

/// Must be registered before runApp so Android can deliver a data-only push
/// even when the Flutter UI has not been created yet.
void registerFirebaseBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Boots Firebase and wires the foreground/background handlers.
///
/// Swallows its own failure on purpose: main.dart awaits this during startup
/// and a Firebase problem (no google-services.json, no network, a device with no
/// Play Services) must not stop the app from opening. Everything below reports
/// through [debugPrint] instead so a broken push setup is visible in the log
/// rather than silently doing nothing.
Future<void> initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('[push] Firebase ready');

    // `init()` registers the foreground, background, opened-app and
    // token-refresh listeners and sets up the local notification channel.
    await PushNotificationService.init();
  } catch (e) {
    debugPrint('[push] setup failed (app will continue without notifications): $e');
  }
}

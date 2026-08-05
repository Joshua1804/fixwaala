import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/enums.dart';
import 'app_preferences_service.dart';
import 'firebase_service.dart';

/// Notifications, local and push.
///
/// Previously local-only, fired from a `StreamBuilder` on the **foreground**
/// device — so a provider learned about a nearby job only while the app was
/// open and they were looking at it, and a customer learned a provider had
/// accepted only while the matching screen was in front of them. That is the
/// difference between a demo and a marketplace.
///
/// FCM now delivers those events from the server (see
/// `functions/notifications.js`). Local notifications remain for foreground
/// display, since Android does not surface a data message on its own.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  static const _channelId = 'fixwaala_alerts';
  static const _channelName = 'Fixwaala alerts';
  static const _channelDescription =
      'Job opportunities, matching updates, and job status changes.';

  bool get _live => FirebaseService.instance.isInitialized;

  Future<void> initialize() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // The channel must exist before any notification targets it, otherwise
    // Android 8+ drops it silently.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );

    _initialized = true;

    if (_live) await _initializePush();
  }

  /// Requests permission and starts listening for pushes.
  ///
  /// On Android 13+ `POST_NOTIFICATIONS` is a runtime permission; without it
  /// every notification — local ones included — is silently discarded.
  Future<void> _initializePush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        showLocalAlert(
          title: notification.title ?? 'Fixwaala',
          body: notification.body ?? '',
        );
      });

      // A token can rotate at any time; a stale one silently stops delivery.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen(_persistToken);
    } catch (error) {
      debugPrint('[NotificationService] Push init failed: $error');
    }
  }

  /// Registers this device against [userId] so the server can reach it, and
  /// subscribes to the topic for their role.
  ///
  /// Call after sign-in — a token registered before auth cannot be attributed
  /// to anybody.
  Future<void> registerDevice({
    required String userId,
    required UserRole role,
  }) async {
    if (kIsWeb || !_live) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) await _persistToken(token, userId: userId);
      await messaging.subscribeToTopic(_topicFor(role));
    } catch (error) {
      debugPrint('[NotificationService] Device registration failed: $error');
    }
  }

  /// Removes this device's token and topic subscriptions on sign-out, so the
  /// next person to use the phone does not receive the previous user's jobs.
  Future<void> unregisterDevice() async {
    if (kIsWeb || !_live) return;
    try {
      final messaging = FirebaseMessaging.instance;
      for (final role in UserRole.values) {
        await messaging.unsubscribeFromTopic(_topicFor(role));
      }
      final token = await messaging.getToken();
      if (token != null) {
        await FirebaseService.instance.firestore
            .collection('deviceTokens')
            .doc(token)
            .delete();
      }
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('[NotificationService] Device unregistration failed: $error');
    }
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  static String _topicFor(UserRole role) => 'role_${role.name}';

  Future<void> _persistToken(String token, {String? userId}) async {
    final uid = userId ?? FirebaseService.instance.auth.currentUser?.uid;
    if (uid == null) return;
    await FirebaseService.instance.firestore
        .collection('deviceTokens')
        .doc(token)
        .set({
          'userId': uid,
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    // The settings toggle previously gated nothing at all.
    if (!AppPreferencesService.instance.notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

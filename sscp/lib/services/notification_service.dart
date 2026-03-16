import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handling is intentionally light; data is persisted by Cloud Function.
  debugPrint('Background notification received: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _activeStudentId;
  bool _initialized = false;
  bool _tokenRefreshSubscribed = false;

  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
        'Notification permission status: ${settings.authorizationStatus}');

    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened from background: ${message.messageId}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'Notification opened from terminated state: ${initialMessage.messageId}');
    }

    _initialized = true;
  }

  Future<void> registerStudentToken({required String studentId}) async {
    _activeStudentId = studentId.trim().toUpperCase();
    if (_activeStudentId == null || _activeStudentId!.isEmpty) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('Unable to fetch FCM token: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    await _upsertToken(
      studentId: _activeStudentId!,
      token: token,
    );

    if (!_tokenRefreshSubscribed) {
      _tokenRefreshSubscribed = true;
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentStudentId = _activeStudentId;
        if (currentStudentId == null || currentStudentId.isEmpty) return;
        await _upsertToken(studentId: currentStudentId, token: newToken);
      });
    }
  }

  Future<void> unregisterStudentToken({required String studentId}) async {
    final normalizedStudentId = studentId.trim().toUpperCase();
    if (normalizedStudentId.isEmpty) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _firestore.collection('students').doc(normalizedStudentId).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (_activeStudentId == normalizedStudentId) {
      _activeStudentId = null;
    }
  }

  Future<void> _upsertToken({
    required String studentId,
    required String token,
  }) async {
    final uid = _auth.currentUser?.uid;
    await _firestore.collection('students').doc(studentId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastFcmToken': token,
      'fcmUid': uid,
      'fcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'marks_uploads',
      'Marks Uploads',
      description: 'Notifications for newly uploaded student marks',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final title =
        message.notification?.title ?? message.data['title'] ?? 'SRU SSCP';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'marks_uploads',
        'Marks Uploads',
        channelDescription: 'Notifications for newly uploaded student marks',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }
}

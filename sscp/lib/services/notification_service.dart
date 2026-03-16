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

  String? _activeRole;
  String? _activeRoleId;
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
      'Notification permission status: ${settings.authorizationStatus}',
    );

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
        'Notification opened from terminated state: ${initialMessage.messageId}',
      );
    }

    _initialized = true;
  }

  // Backward compatible wrappers used by existing student flow.
  Future<void> registerStudentToken({required String studentId}) {
    return registerRoleToken(role: 'student', roleId: studentId);
  }

  Future<void> unregisterStudentToken({required String studentId}) {
    return unregisterRoleToken(role: 'student', roleId: studentId);
  }

  Future<void> registerRoleToken({
    required String role,
    required String roleId,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final normalizedRoleId = roleId.trim().toUpperCase();
    if (normalizedRoleId.isEmpty) return;

    _activeRole = normalizedRole;
    _activeRoleId = normalizedRoleId;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('Unable to fetch FCM token: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    await _upsertToken(
      role: normalizedRole,
      roleId: normalizedRoleId,
      token: token,
    );

    if (!_tokenRefreshSubscribed) {
      _tokenRefreshSubscribed = true;
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentRole = _activeRole;
        final currentRoleId = _activeRoleId;
        if (currentRole == null || currentRoleId == null) return;
        if (currentRoleId.isEmpty) return;
        await _upsertToken(
          role: currentRole,
          roleId: currentRoleId,
          token: newToken,
        );
      });
    }
  }

  Future<void> unregisterRoleToken({
    required String role,
    required String roleId,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final normalizedRoleId = roleId.trim().toUpperCase();
    if (normalizedRoleId.isEmpty) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    final uid = _auth.currentUser?.uid;
    final roleCollection = _collectionForRole(normalizedRole);

    await _firestore.collection(roleCollection).doc(normalizedRoleId).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (uid != null && uid.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (_activeRole == normalizedRole && _activeRoleId == normalizedRoleId) {
      _activeRole = null;
      _activeRoleId = null;
    }
  }

  Future<void> _upsertToken({
    required String role,
    required String roleId,
    required String token,
  }) async {
    final uid = _auth.currentUser?.uid;
    final roleCollection = _collectionForRole(role);

    final rolePayload = {
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastFcmToken': token,
      'fcmUid': uid,
      'fcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection(roleCollection)
        .doc(roleId)
        .set(rolePayload, SetOptions(merge: true));

    if (uid != null && uid.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmToken': token,
        'fcmUid': uid,
        'fcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'fcmRole': role,
        'fcmRoleId': roleId,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    if (value == 'feepayment' || value == 'fee payment') {
      return 'fee_payment';
    }
    return value;
  }

  String _collectionForRole(String role) {
    switch (role) {
      case 'student':
        return 'students';
      case 'faculty':
        return 'faculty';
      case 'admin':
        return 'admin';
      case 'fee_payment':
        return 'feePayments';
      default:
        return 'users';
    }
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
      'sscp_notifications',
      'SSCP Notifications',
      description: 'Role-based notifications for SSCP users',
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
        'sscp_notifications',
        'SSCP Notifications',
        channelDescription: 'Role-based notifications for SSCP users',
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

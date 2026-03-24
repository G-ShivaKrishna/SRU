# SRU SSCP Flutter App - lib/ Overview

This file is a single-file developer reference for the app under `lib/`.

## Table of Contents

1. [App role and architecture summary](#1-app-role-and-architecture-summary)
2. [Entry point - lib/main.dart](#2-entry-point---libmaindart)
3. [Configuration - lib/config/dev_config.dart](#3-configuration---libconfigdev_configdart)
4. [Splash Animation - lib/splash_animation.dart](#4-splash-animation---libsplash_animationdart)
5. [Session persistence - lib/services/session_service.dart](#5-session-persistence---libservicessession_servicedart)
6. [User identification cache - lib/services/user_service.dart](#6-user-identification-cache---libservicesuser_servicedart)
7. [Notification system - lib/services/notification_service.dart](#7-notification-system---libservicesnotification_servicedart)
8. [Audit logging - model & service](#8-audit-logging---model--service)
9. [Main role apps](#9-main-role-apps)
10. [Utilities & helpers](#10-utilities--helpers)
11. [Data storage patterns](#11-data-storage-patterns)
12. [Startup + app flow](#12-startup--app-flow)
13. [Maintenance notes](#13-maintenance-notes)

## 1. App role and architecture summary

SRU SSCP is a role-based campus portal: students, faculty, admin, fee-payment.

Features:
- Firebase Auth (login by role)
- Firestore data model for users/roles/marks/attendance/fees/grievances
- Firebase Cloud Messaging (FCM) + local notifications
- Session persistence (SharedPreferences)
- Audit logging for critical operations
- Role-based home dashboards + feature pages


## 2. Entry point - `lib/main.dart`

- `main()`:
  - `WidgetsFlutterBinding.ensureInitialized()`
  - `_bootstrapServices()`:
    - `Firebase.initializeApp()`
    - `NotificationService.instance.initialize()`
  - `runApp(MyApp())`
- `MyApp`: `MaterialApp` using `SplashAnimationScreen` with destination:
  - `DevConfig.bypassLogin` based static route override
  - `SessionRoute` for normal mode
- `_SessionRoute`:
  - waits for auth state + local saved session
  - checks Firestore `users/{uid}` to resolve role
  - route  to: `StudentHome`, `FacultyHome`, `AdminHome`, `FeePaymentHome`, or `RoleSelectionScreen`


## 3. Configuration - `lib/config/dev_config.dart`

Dev-only flags:
- `bypassLogin` (default false)
- `useDemoData` (true when bypass enabled)
- `defaultRole`: `admin` by default
- route names for each role


## 4. Splash Animation - `lib/splash_animation.dart`

- `SplashAnimationScreen` shows animated entry screen
- auto-navigates to `widget.next` after completion
- health check: includes fallback `NextScreen` in local standalone `main` function


## 5. Session persistence - `lib/services/session_service.dart`

Uses `shared_preferences`:
- saved keys:
  - `saved_role`, `saved_uid`, `saved_role_id`, `saved_email`
- APIs:
  - `saveSession()`, `saveRole()`, `getSession()`, `getSavedRole()`, `clearRole()`
- role normalization ensures `fee_payment` variants are consistent


## 6. User identification cache - `lib/services/user_service.dart`

In-memory cache of current user:
- `_currentUserId`, `_currentUserRole`, `_currentUserData`
- `fetchAndCacheUserId()` reads Firestore `users/{uid}` and extracts role data
- used for routing and accessing role collections


## 7. Notification system - `lib/services/notification_service.dart`

- Uses `firebase_messaging` and `flutter_local_notifications`
- `initialize()` sets:
  - `FirebaseMessaging.onBackgroundMessage(...)`
  - local channel `sscp_notifications`
  - notification permissions
  - foreground `onMessage` local display
  - `onMessageOpenedApp` and `getInitialMessage`
- role token registration:
  - `registerRoleToken()`, `unregisterRoleToken()` and `registerStudentToken()` wrappers
- stores token metadata in Firestore role collection + `users` doc
- onboarding code already included in role homes (calls `register/unregister`)


## 8. Audit logging - model & service

`lib/models/audit_log_model.dart`:
- `AuditLogEntry` model with Firestore conversions and `getDescription()`

`lib/services/audit_log_service.dart`:
- generic `logActivity()` to `auditLogs`
- methods for marks, fees, profile updates, grievances, feedback
- query stream helper with simple filters


## 9. Main role apps

### Role selection UI
`lib/screens/role_selection_screen.dart`
- card-style navigation to each role
- uses `DevConfig.bypassLogin` to decide login vs direct home

### Student flow
- `lib/roles/student/student_login_screen.dart`
- `lib/roles/student/student_home.dart`
- loads `students/{rollNo}`; computes CGPA, attendance, backlogs
- registers FCM token for student role
- sub-screens: attendance/results/feedback/grievance/subject registration etc.

### Faculty flow
- `lib/roles/faculty/faculty_login_screen.dart`
- `lib/roles/faculty/faculty_home.dart`
- loads `faculty/{facultyId}`
- registers FCM token for faculty role
- sub-screens: attendance management, marks entry, feedback, etc.

### Admin flow
- `lib/roles/admin/admin_login_screen.dart`
- `lib/roles/admin/admin_home.dart`
- loads `admin/{adminId}`
- manages student/faculty/source data and windows
- includes audit logging for managed operations

### Fee-payment flow
- `lib/roles/fee_payment/fee_payment_login_screen.dart`
- `lib/roles/fee_payment/fee_payment_home.dart`
- manages fees windows and payment status


## 10. Utilities in `lib/utils`

- `file_save_io.dart`, `file_save_stub.dart`, `file_save_web.dart`: cross-platform file save
- `web_download_*`: web download adapter
- `memo_pdf_generator.dart`: PDF generator for memos/reports
- `html_preview_screen.dart`: shows generated HTML


## 11. Firestore schema overview (from code patterns)

- `users` (uid→role, roleId, fcm tokens)
- `students`, `faculty`, `admin`, `feePayments` (profile data)
- `studentMarks`, `attendance`, `cieMemoReleases`, `supplyMarks`, `feedback`, `grievances`
- `auditLogs`, `subjects`, `courses`, `attendanceEditRequests`, `grievances`, etc.


## 12. Quick maintenance notes

- Keep `DevConfig.bypassLogin=false` for production.
- Ensure `Firebase` and `NotificationService` initialize successfully before UI.
- Android `POST_NOTIFICATIONS` is already in manifest.
- `flutter analyze` may show lint warnings; no compile-showstopper errors.

## 13. Whole app context (beyond lib)

### Android platform setup (`android/`)
- `android/app/src/main/AndroidManifest.xml`:
  - required permissions (`INTERNET`, `POST_NOTIFICATIONS`).
  - `MainActivity` configuration with flutter embedding v2.
  - custom URL schemes and deep links.
- `android/app/build.gradle.kts` and `android/build.gradle.kts`:
  - app ID, minSdk, targetSdk, compileSdk
  - dependencies: firebase, play-services, Flutter embedding.
- `android/app/google-services.json`: Firebase Android config.
- `android/gradle.properties`: flags for performance, multiDex.

### iOS platform setup (`ios/`)
- `ios/Runner/Info.plist`:
  - permission descriptions for notifications, camera, location etc.
- `ios/Podfile`: Flutter pods and iOS platform target.
- `ios/Runner/GoogleService-Info.plist`: Firebase iOS config.
- `ios/Runner/AppDelegate.swift` or generated Flutter plugin registration.

### Flutter root config
- `pubspec.yaml`:
  - dependency versions (firebase_core, firebase_auth, cloud_firestore, firebase_messaging, flutter_local_notifications, shared_preferences, url_launcher etc.)
  - assets referenced in UI (e.g., `assets/images/logo.png`).
- `analysis_options.yaml`: lint rules, code style.

### Backend / functions
- `functions/index.js` (Cloud Functions) for server-side events and notifications.
- `functions/package.json`: node dependencies for cloud functions.
- Firebase hosting and Firestore security via `firebase.json` + `firestore.rules`.

### Testing
- `test/widget_test.dart`: sample widget test.

## 14. Fast lookup for “what is used where”

### Core runtime flow
- `main.dart` → `SplashAnimationScreen` → `_SessionRoute` → role home.
- `SessionService` and `UserService` are central caches.

### Auth + session
- `screens/login_screen.dart` + role login screens in each role folder.
- `SessionService.saveSession()` after successful login.
- `UserService.fetchAndCacheUserId()` is used for role DB mapping.

### Firestore read/write surfaces
- Role home screens read from role collections and `courses`, `subjects`, `attendance`, etc.
- Action methods call services: `student_course_service`, `faculty_assignment_service`, `student_promotions_service`, `feedback_service`.
- `AuditLogService` writes to `auditLogs` for key operations.

### FCM + local notifications
- `NotificationService.initialize()` in app bootstrap
- Role page logins call `registerRoleToken` / `unregisterRoleToken`.
- `notifications` are displayed via `flutter_local_notifications` when app is foreground.

### Utilities
- `utils/*`: file save and PDF utilities used in download/export operations (attendance reports, memo PDFs, etc.)

### Complete app state ownership
- Auth identity in `FirebaseAuth.instance.currentUser`.
- Role context in `SessionService` and `UserService`.
- Ongoing operation caches by services for responsive UI.

---

## 15. How to use this README

- Open this file in editor and use TOC links for navigation.
- Add sections for newly added role pages or backend changes.
- Keep this updated when Firestore collections or auth roles change.


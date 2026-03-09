import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'config/dev_config.dart';
import 'splash_animation.dart';
import 'screens/role_selection_screen.dart';
import 'roles/student/student_home.dart';
import 'roles/admin/admin_home.dart';
import 'roles/fee_payment/fee_payment_home.dart';
import 'roles/faculty/faculty_home.dart';
import 'services/session_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRU SSCP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: SplashAnimationScreen(next: _getDevHome() ?? const _SessionRoute()),
    );
  }

  /// Returns a specific home only when DevConfig.bypassLogin is enabled.
  /// Returns null in normal (non-dev) mode so the session route handles it.
  Widget? _getDevHome() {
    if (!DevConfig.bypassLogin) return null;
    switch (DevConfig.defaultRole.toLowerCase()) {
      case 'admin':
        return const AdminHome();
      case 'student':
        return const StudentHome();
      case 'fee payment':
      case 'fee_payment':
      case 'feepayment':
        return const FeePaymentHome();
      default:
        return null;
    }
  }
}

/// Checks Firebase auth state + saved role and routes to the right home screen.
class _SessionRoute extends StatefulWidget {
  const _SessionRoute();

  @override
  State<_SessionRoute> createState() => _SessionRouteState();
}

class _SessionRouteState extends State<_SessionRoute> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final user = FirebaseAuth.instance.currentUser;
    final role = await SessionService.getSavedRole();

    if (!mounted) return;

    Widget dest;
    if (user != null && role != null) {
      await UserService.fetchAndCacheUserId();
      switch (role) {
        case 'admin':
          dest = const AdminHome();
          break;
        case 'student':
          dest = const StudentHome();
          break;
        case 'faculty':
          dest = const FacultyHome();
          break;
        case 'fee_payment':
          dest = const FeePaymentHome();
          break;
        default:
          dest = const RoleSelectionScreen();
      }
    } else {
      dest = const RoleSelectionScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFD9E6F2),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

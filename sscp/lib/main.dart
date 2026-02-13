import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/dev_config.dart';
import 'splash_animation.dart';
import 'screens/role_selection_screen.dart';
import 'roles/student/student_home.dart';
import 'roles/admin/admin_home.dart';

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
      home: SplashAnimationScreen(next: _getHome()),
    );
  }

  Widget _getHome() {
    if (!DevConfig.bypassLogin) {
      return const RoleSelectionScreen();
    }

    // Bypass login - route to appropriate dashboard
    switch (DevConfig.defaultRole.toLowerCase()) {
      case 'admin':
        return const AdminHome();
      case 'student':
        return const StudentHome();
      default:
        return const RoleSelectionScreen();
    }
  }
}

import 'package:flutter/material.dart';
import '../screens/role_selection_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _headerBlue = Color(0xFF1e3a5f);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSCP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _headerBlue,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

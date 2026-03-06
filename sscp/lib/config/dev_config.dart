class DevConfig {
  // Set to true to bypass login screens during development
  static const bool bypassLogin = true;

  // Render demo data in actual pages when bypassing login
  // Automatically true when bypassLogin is true,
  static const bool useDemoData = bypassLogin;

  // Default role when bypassing login (ignored if bypass applies to all roles)
  static const String defaultRole = 'admin';

  // Dashboard routes (match each dashboard widget routeName)
  static const String studentDashboardRoute = '/studentHome';
  static const String facultyDashboardRoute = '/facultyHome';
  static const String adminDashboardRoute = '/adminHome';
}

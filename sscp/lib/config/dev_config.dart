class DevConfig {
  // Set to true to bypass login screens during development
  static const bool bypassLogin = false;

  // Render demo data in actual pages when bypassing login
  static const bool useDemoData = true;

  // Default role when bypassing login (ignored if bypass applies to all roles)
  static const String defaultRole = 'admin';

  // Dashboard routes (match each dashboard widget routeName)
  static const String studentDashboardRoute = '/studentHome';
  static const String facultyDashboardRoute = '/facultyHome';
  static const String adminDashboardRoute = '/adminHome';
}

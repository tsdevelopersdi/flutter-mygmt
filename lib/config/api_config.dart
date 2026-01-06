/// API Configuration
/// Change the base URL here to update all API endpoints across the app
class ApiConfig {
  // Base API URL - Change this to update all API endpoints
  // static const String baseUrl = 'http://10.28.24.173:45000';
  static const String baseUrl = 'http://mobileabsen.gmt.id:45000';
  // static const String baseUrl = 'http://10.10.28.121:45000';
  // static const String baseUrl = 'http://10.28.24.173:45000';

  // Auth endpoints
  static const String loginEndpoint = '$baseUrl/login';
  static const String logoutEndpoint = '$baseUrl/logout';
  static const String tokenRefreshEndpoint = '$baseUrl/token';

  // Attendance endpoint
  static const String attendanceEndpoint = '$baseUrl/attendance';
}

import 'package:jwt_decode/jwt_decode.dart';

/// Helper class for JWT token operations
class JwtHelper {
  /// Decode JWT token and extract expiration time
  /// Returns null if token is invalid or doesn't have expiration
  static DateTime? getTokenExpiration(String token) {
    try {
      if (token.isEmpty) return null;
      
      // Decode the JWT token
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      
      // Get expiration timestamp (exp claim)
      final exp = payload['exp'];
      if (exp == null) return null;
      
      // Convert Unix timestamp to DateTime
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      print('Error decoding JWT token: $e');
      return null;
    }
  }

  /// Check if token is expired (with optional buffer)
  /// bufferMinutes: refresh token this many minutes before actual expiry
  /// bufferSeconds: refresh token this many seconds before actual expiry
  /// Returns true if token is expired or will expire within buffer time
  static bool isTokenExpired(String token, {int bufferMinutes = 5, int bufferSeconds = 0}) {
    try {
      final expiration = getTokenExpiration(token);
      if (expiration == null) {
        // If we can't get expiration, consider it expired
        return true;
      }

      // Add buffer time to current time
      final now = DateTime.now();
      final totalBufferSeconds = (bufferMinutes * 60) + bufferSeconds;
      final bufferTime = now.add(Duration(seconds: totalBufferSeconds));

      // Token is considered expired if expiration is before buffer time
      return expiration.isBefore(bufferTime);
    } catch (e) {
      print('Error checking token expiration: $e');
      return true; // Consider expired on error
    }
  }

  /// Check if token will expire soon (within buffer time)
  /// This is useful for proactive token refresh
  static bool isTokenExpiringSoon(String token, {int bufferMinutes = 5}) {
    return isTokenExpired(token, bufferMinutes: bufferMinutes);
  }

  /// Get remaining time until token expires
  /// Returns null if token is invalid or already expired
  static Duration? getTimeUntilExpiration(String token) {
    try {
      final expiration = getTokenExpiration(token);
      if (expiration == null) return null;

      final now = DateTime.now();
      if (expiration.isBefore(now)) {
        // Already expired
        return Duration.zero;
      }

      return expiration.difference(now);
    } catch (e) {
      print('Error getting time until expiration: $e');
      return null;
    }
  }

  /// Print token expiration info for debugging
  static void printTokenInfo(String token, {String label = 'Token'}) {
    final expiration = getTokenExpiration(token);
    if (expiration == null) {
      print('$label: Invalid or no expiration');
      return;
    }

    final now = DateTime.now();
    final timeUntilExpiry = expiration.difference(now);
    final isExpired = expiration.isBefore(now);

    print('$label Info:');
    print('  Expires at: $expiration');
    print('  Current time: $now');
    print('  Time until expiry: ${timeUntilExpiry.inMinutes} minutes');
    print('  Is expired: $isExpired');
  }
}

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'models.dart';

class ActivityService {
  /// Fetch recent activity records from the API
  /// Returns a list of ActivityRecord or throws an exception
  static Future<List<ActivityRecord>> fetchRecentActivities() async {
    try {
      print('\n📋 Fetching recent activities from API...');

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken') ?? '';
      final email = prefs.getString('email') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('No access token found. Please login again.');
      }

      if (email.isEmpty) {
        throw Exception('No email found. Please login again.');
      }

      final url = '${ApiConfig.baseUrl}/recent/$email';
      print('   URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('   Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('   Response: ${response.body}');

        // Handle both array and object with data property
        List<dynamic> activityList;
        
        if (responseData is List) {
          activityList = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          activityList = responseData['data'] as List<dynamic>;
        } else {
          throw Exception('Invalid response format');
        }

        final activities = activityList
            .map((item) => ActivityRecord.fromJson(item as Map<String, dynamic>))
            .toList();

        print('✅ Successfully fetched ${activities.length} activities');
        return activities;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        throw Exception('Failed to fetch activities: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching activities: $e');
      rethrow;
    }
  }
}

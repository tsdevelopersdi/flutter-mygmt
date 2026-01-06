import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'attendance_camera_page.dart';
import '../utils/jwt_helper.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:developer_mode/developer_mode.dart';
import '../config/api_config.dart';
import '../config/activity_service.dart';
import '../config/models.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onLogout;
  const HomePage({Key? key, this.onLogout}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  String _userEmail = '';
  bool _sessionExpired = false; // Track if session has expired
  List<ActivityRecord> _recentActivities = [];
  bool _loadingActivities = false;
  String? _activitiesError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRecentActivities();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('name') ?? 'User';
      _userEmail = prefs.getString('email') ?? '';
    });
  }

  Future<void> _fetchRecentActivities() async {
    if (!mounted) return;
    
    setState(() {
      _loadingActivities = true;
      _activitiesError = null;
    });

    try {
      final activities = await ActivityService.fetchRecentActivities();
      if (mounted) {
        setState(() {
          _recentActivities = activities.take(20).toList();
          _loadingActivities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activitiesError = e.toString();
          _loadingActivities = false;
        });
      }
      print('Error loading activities: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      print('\n🚪 LOGOUT PROCESS STARTED');
      print('   Current context mounted: $mounted');

      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');

      // 1. Call server api to destroy session
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          print('📤 Sending logout request to server...');
          final response = await http.delete(
            Uri.parse(ApiConfig.logoutEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          );

          print('📥 Server Logout Response: ${response.statusCode}');
          if (response.statusCode == 204 || response.statusCode == 200) {
            print('✅ Server session destroyed successfully');
          } else {
            print('⚠️ Server logout returned status: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error calling server logout: $e');
          // Continue with local logout even if server fails
        }
      } else {
        print('⚠️ No refresh token found, skipping server logout');
      }

      // 2. Clear all local authentication data
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('email');
      await prefs.remove('name');
      await prefs.remove('username'); // For backward compatibility

      print('✅ All local authentication data cleared');

      // Show message to user and trigger logout
      if (mounted) {
        print('📱 Showing snackbar message');

        try {
          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          print('✅ Snackbar shown successfully');
        } catch (e) {
          print('⚠️  Error showing snackbar: $e');
        }

        // Wait a bit for the snackbar to show
        await Future.delayed(Duration(milliseconds: 300));

        // Trigger the logout callback
        print('🔄 Calling onLogout callback');
        try {
          widget.onLogout?.call();
          print('✅ Logout callback triggered successfully');
        } catch (e, stackTrace) {
          print('❌ ERROR calling onLogout callback: $e');
          print('   Stack trace: $stackTrace');
        }
      } else {
        print('⚠️  Widget not mounted, skipping UI updates');
      }
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in _handleLogout: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  /// Ensure we have a valid access token
  /// Only refreshes if token is expired or expiring soon
  /// Returns true if we have a valid token, false otherwise
  Future<bool> _ensureValidToken() async {
    try {
      print('\n🔍 Checking access token validity...');

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        print('❌ No access token found');
        return false;
      }

      // Check if token is expired or expiring soon (within 30 seconds)
      final isExpired = JwtHelper.isTokenExpired(accessToken, bufferMinutes: 0, bufferSeconds: 5);

      if (!isExpired) {
        // Token is still valid, no need to refresh
        final timeUntilExpiry = JwtHelper.getTimeUntilExpiration(accessToken);
        print('✅ Access token is still valid');
        print(
          '   Time until expiry: ${timeUntilExpiry?.inMinutes ?? 0} minutes',
        );
        print('   Skipping refresh - using existing token');
        return true;
      }

      // Token is expired or expiring soon, need to refresh
      print('⏰ Access token is expired or expiring soon');
      print('   Attempting to refresh...');

      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        print('✅ Token refreshed successfully');
        return true;
      } else {
        print('❌ Token refresh failed');
        return false;
      }
    } catch (e) {
      print('❌ Error in _ensureValidToken: $e');
      return false;
    }
  }

  Future<bool> _refreshAccessToken() async {
    try {
      print('\n========================================');
      print('🔄 REFRESH TOKEN PROCESS STARTED');
      print('========================================');

      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken') ?? '';
      final oldAccessToken = prefs.getString('accessToken') ?? '';

      // Mask tokens for security (show first 20 and last 10 chars)
      String maskToken(String token) {
        if (token.isEmpty) return 'EMPTY';
        if (token.length <= 30) return '${token.substring(0, 5)}...';
        return '${token.substring(0, 20)}...${token.substring(token.length - 10)}';
      }

      print('📋 Current State:');
      print('   Old Access Token: ${maskToken(oldAccessToken)}');
      print('   Refresh Token: ${maskToken(refreshToken)}');

      if (refreshToken.isEmpty) {
        print('❌ FAILED: No refresh token available');
        print('========================================\n');
        return false;
      }

      print('\n📤 Sending Request:');
      print('   URL: ${ApiConfig.tokenRefreshEndpoint}');
      print('   Method: POST');
      print('   Body: { "refreshToken": "${maskToken(refreshToken)}" }');

      final response = await http.post(
        Uri.parse(ApiConfig.tokenRefreshEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      print('\n📥 Response Received:');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle both possible response formats
        final newAccessToken =
            responseData['accessToken'] ?? responseData['newAccessToken'];

        if (newAccessToken != null) {
          // Save new access token
          await prefs.setString('accessToken', newAccessToken);
          print('\n✅ SUCCESS:');
          print('   New Access Token: ${maskToken(newAccessToken)}');
          print('   Token saved to SharedPreferences');
          print('========================================\n');
          return true;
        } else {
          print('\n❌ FAILED: No access token in response');
          print('   Response keys: ${responseData.keys.toList()}');
          print('========================================\n');
          return false;
        }
      }

      print('\n❌ FAILED: Invalid status code ${response.statusCode}');
      if (response.statusCode == 403 || response.statusCode == 401) {
        print('⚠️  REFRESH TOKEN EXPIRED - Triggering logout');
        print('========================================\n');
        // Mark session as expired
        _sessionExpired = true;
        // Trigger logout asynchronously
        Future.microtask(() => _handleLogout());
        return false;
      }
      print('========================================\n');
      return false;
    } catch (e, stackTrace) {
      print('\n❌ ERROR: Exception occurred');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('========================================\n');
      return false;
    }
  }

  Future<void> _submitAttendance(dynamic image, dynamic position, String caption, String? selectedOption) async {
    bool dialogShown = false;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF667EEA)),
                  SizedBox(height: 16),
                  Text('Submitting attendance...'),
                ],
              ),
            ),
          ),
        ),
      );
      dialogShown = true;

      // Ensure we have a valid access token (only refreshes if needed)
      print('\n� Ensuring valid access token...');
      final hasValidToken = await _ensureValidToken();

      // Check if session expired during token validation
      if (_sessionExpired) {
        print('🚫 Session expired - aborting attendance submission');
        // Close loading dialog
        if (dialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        // Don't show additional error - logout handler already showed message
        return;
      }

      if (!hasValidToken) {
        print('❌ Failed to get valid access token - aborting submission');
        // Close loading dialog
        if (dialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        }
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authentication failed. Please try again.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';
      final email = prefs.getString('email') ?? '';
      final name = prefs.getString('name') ?? '';

      print('=== ATTENDANCE SUBMISSION ===');
      print('Email: $email');
      print('Name: $name');
      print('Image path: ${image.path}');
      if (position != null) {
        print('Location: ${position.latitude}, ${position.longitude}');
      }
      print('Caption: $caption');
      print('Selected Option: $selectedOption');
      
      // Prepare multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.attendanceEndpoint),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));

      // Add form fields
      request.fields['email'] = email;
      request.fields['name'] = name;
      request.fields['timestamp'] = DateTime.now().toIso8601String();
      request.fields['caption'] = caption;
      request.fields['selectedOption'] = selectedOption ?? '';

      if (position != null) {
        request.fields['latitude'] = position.latitude.toString();
        request.fields['longitude'] = position.longitude.toString();
        request.fields['accuracy'] = position.accuracy.toString();
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Close loading dialog
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);

          String locationText = 'Location not available';
          if (position != null) {
            locationText =
                'Lat: ${position.latitude.toStringAsFixed(6)}, '
                'Long: ${position.longitude.toStringAsFixed(6)}';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✓ Attendance submitted successfully!'),
                    SizedBox(height: 4),
                    Text(locationText, style: TextStyle(fontSize: 12)),
                  ],
                ),
                backgroundColor: Color(0xFF4CAF50),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }

          print('✓ Attendance submitted successfully');
          
          // Refresh recent activities
          _fetchRecentActivities();
        } catch (e) {
          print('Error parsing success response: $e');
        }
      } else {
        // Error response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ?? 'Failed to submit attendance';
          print('✗ Server error: $errorMessage');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } catch (e) {
          print(
            '✗ Server error (status ${response.statusCode}): ${response.body}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Server error (${response.statusCode})'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('✗ Error submitting attendance: $e');
      print('Stack trace: $stackTrace');

      // Ensure dialog is closed
      if (dialogShown && mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          print('Error closing dialog: $e');
        }
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit attendance. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _openCamera() async {
    bool isFakeLocation = await DetectFakeLocation().detectFakeLocation();
    bool isJailbroken = await DeveloperMode.isJailbroken;
    bool isDeveloperMode = await DeveloperMode.isDeveloperMode;

    // If fake GPS is detected, show error and return
    if (isFakeLocation || isJailbroken || isDeveloperMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cheating attempt is detected. Camera cannot be opened.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    // If no fake GPS detected, open camera
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AttendanceCameraPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final image = result['image'];
      final position = result['position'];
      final caption = result['caption'] ?? '';
      final selectedOption = result['selectedOption'];

      // Submit attendance to API
      await _submitAttendance(image, position, caption, selectedOption);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);
    final dateString = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hallo 👋👋👋',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Time and Date Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            timeString,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            dateString,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            SizedBox(height: 60), // Space for floating button
                            // Recent Activity Section
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Recent Activity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // Activity List
                            Expanded(
                              child: _buildActivityList(),
                            ),
                          ],
                        ),
                      ),

                      // Floating Camera Button (Centered at top)
                      Positioned(
                        top: -30,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _openCamera,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF667EEA).withOpacity(0.5),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    // Show loading state
    if (_loadingActivities) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF667EEA),
        ),
      );
    }

    // Show error state
    if (_activitiesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load activities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _activitiesError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchRecentActivities,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF667EEA),
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (_recentActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              color: Colors.grey[400],
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No activities found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Show activity list
    return ListView.builder(
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        final statusColor = _getStatusColor(activity.status);

        return _buildActivityItem(
          date: activity.date,
          checkIn: activity.checkIn,
          checkOut: activity.checkOut,
          status: activity.status,
          // accuracy: activity.accuracy,
          // photo : activity.photo,
          caption: activity.caption,
          statusColor: statusColor,
        );
      },
    );
  }

  /// Get color for status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on time':
      case 'ontime':
        return Color(0xFF4CAF50); // Green
        // return Color(0xFF4CAF50); // Green
      case 'late':
        // return Color(0xFFFFA726); // Orange
        return Color(0xFF4CAF50); // Orange
      case 'absent':
        // return Color(0xFFEF5350); // Red
        return Color(0xFF4CAF50); // Red
      default:
        // return Color(0xFF9E9E9E); // Grey
        return Color(0xFF4CAF50); // Grey
    }
  }

  Widget _buildActivityItem({
    required String date,
    required String checkIn,
    required String checkOut,
  //   String? accuracy,
  // String? photo,
    required String caption,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'lokasi: $caption',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

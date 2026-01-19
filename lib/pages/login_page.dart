import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/api_config.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginPage({Key? key, this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Get device ID
      final deviceId = await _getDeviceId();
      print('Device ID for Login: $deviceId');

      final Map<String, dynamic> requestData = {
        'email': username, 
        'password': password
      };
      
      if (deviceId != null) {
        requestData['android_id'] = deviceId;
      }

      final requestBody = jsonEncode(requestData);
      print('\n========================================');
      print('🔐 LOGIN REQUEST');
      print('========================================');
      print('URL: ${ApiConfig.loginEndpoint}');
      print('Body: $requestBody');
      
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('\n📥 LOGIN RESPONSE');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      final Map<String, dynamic> resp = jsonDecode(response.body);
      print('\n📋 Parsed Response Structure:');
      print('   Keys in response: ${resp.keys.toList()}');
      print('   success: ${resp['success']}');
      print('   accessToken exists: ${resp['accessToken'] != null}');
      print('   refreshToken exists: ${resp['refreshToken'] != null}');
      print('   user exists: ${resp['user'] != null}');
      
      if (resp['user'] != null) {
        print('   user keys: ${resp['user'].keys.toList()}');
      }

      if (resp['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        
        print('\n💾 Saving to SharedPreferences:');
        
        // Save JWT tokens
        if (resp['accessToken'] != null) {
          await prefs.setString('accessToken', resp['accessToken']);
          print('   ✅ Access token saved (length: ${resp['accessToken'].toString().length})');
        } else {
          print('   ❌ No accessToken in response!');
        }
        
        if (resp['refreshToken'] != null) {
          await prefs.setString('refreshToken', resp['refreshToken']);
          print('   ✅ Refresh token saved (length: ${resp['refreshToken'].toString().length})');
        } else {
          print('   ⚠️  WARNING: No refreshToken in response!');
          print('   This means your server is NOT returning a refresh token.');
          print('   Please check your backend /login endpoint.');
        }
        
        // Save user information
        if (resp['user'] != null) {
          await prefs.setString('email', resp['user']['email'] ?? '');
          await prefs.setString('name', resp['user']['name'] ?? '');
          await prefs.setString('role', resp['user']['role'] ?? '');
          await prefs.setString('nik', resp['user']['nik'] ?? '');
          await prefs.setString('status_site', resp['user']['status'] ?? '');
          await prefs.setString('department', resp['user']['department'] ?? '');
          print('   ✅ User email saved: ${resp['user']['email']}');
          print('   ✅ User name saved: ${resp['user']['name']}');
          print('   ✅ User role saved: ${resp['user']['role']}');
          print('   ✅ User nik saved: ${resp['user']['nik']}');
          print('   ✅ User status_site saved: ${resp['user']['status']}');
          print('   ✅ User department saved: ${resp['user']['department']}');
        } else {
          print('   ⚠️  WARNING: No user object in response!');
        }
        
        print('========================================\n');
        widget.onLoginSuccess?.call();
      } else {
        print('❌ Login failed: ${resp['message'] ?? resp['error']}');
        print('========================================\n');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp['message'] ?? resp['error'] ?? "Invalid username or password"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Exception during login: $e');
      print('========================================\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login failed: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.8],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Logo/Icon with modern design
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/gmt.png',
                        width: 64,
                        height: 64,
                        // color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 24),
                    // Welcome text
                    Text(
                      "Mobile Attendance",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "PT. Global Makara Teknik",
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    SizedBox(height: 40),
                    // Login card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Username field
                              TextFormField(
                                controller: _usernameController,
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: Colors.grey[600],
                                  ),
                                  labelText: "Username",
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 20),
                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey[600],
                                  ),
                                  labelText: "Password",
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF667EEA),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          "Login",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

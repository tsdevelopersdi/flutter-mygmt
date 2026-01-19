import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onLogout;
  const ProfilePage({Key? key, this.onLogout}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  String _userNik = '';
  String _userStatus = '';
  String _userDepartment = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    print('\n📋 Loading Profile Data from SharedPreferences:');
    print('   name: ${prefs.getString('name')}');
    print('   email: ${prefs.getString('email')}');
    print('   role: ${prefs.getString('role')}');
    print('   nik: ${prefs.getString('nik')}');
    print('   status_site: ${prefs.getString('status_site')}');
    print('   department: ${prefs.getString('department')}');
    
    setState(() {
      _userName = prefs.getString('name') ?? 'User';
      _userEmail = prefs.getString('email') ?? 'user@example.com';
      _userRole = prefs.getString('role') ?? 'N/A';
      _userNik = prefs.getString('nik') ?? 'N/A';
      _userStatus = prefs.getString('status_site') ?? 'N/A';
      _userDepartment = prefs.getString('department') ?? 'N/A';
    });
    
    print('   Loaded values:');
    print('   _userName: $_userName');
    print('   _userEmail: $_userEmail');
    print('   _userRole: $_userRole');
    print('   _userNik: $_userNik');
    print('   _userStatus: $_userStatus');
    print('   _userDepartment: $_userDepartment');
  }

  @override
  Widget build(BuildContext context) {
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
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Profile Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Color(0xFF667EEA),
                ),
              ),
              SizedBox(height: 16),

              // User Name
              Text(
                _userName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              // User Email
              Text(
                _userEmail,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 32),

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Profile Info Cards
                        _buildInfoCard(
                          icon: Icons.badge,
                          label: 'NIK',
                          value: _userNik,
                        ),
                        SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.email,
                          label: 'Email',
                          value: _userEmail,
                        ),
                        SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.work,
                          label: 'Role',
                          value: _userRole,
                        ),
                        SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.apartment,
                          label: 'Department',
                          value: _userDepartment,
                        ),
                        SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.location_on,
                          label: 'Status Site',
                          value: _userStatus,
                        ),

                        SizedBox(height: 32),

                        // Settings Section
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),

                        _buildSettingsItem(
                          icon: Icons.lock,
                          title: 'Change Password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangePasswordPage(
                                  onLogout: widget.onLogout,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildSettingsItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          onTap: () {
                            // TODO: Implement notifications settings
                          },
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
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
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
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Color(0xFF667EEA),
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
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
            Icon(
              icon,
              color: Color(0xFF667EEA),
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

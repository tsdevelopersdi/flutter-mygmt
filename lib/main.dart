import 'package:inspection_app_gmt_3/sublist_pages/hd_list_page.dart';
import 'sublist_pages/adt_list_page.dart';
import 'sublist_pages/excavator_list_page.dart';
import 'sublist_pages/dozer_list_page.dart';
import 'sublist_pages/grader_list_page.dart';
import 'sublist_pages/hdt_list_page.dart';
import 'sublist_pages/dt_list_page.dart';
import 'sublist_pages/wl_list_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/menu_page.dart';
import 'pages/app_selection_page.dart';
import 'pages/profile_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:developer_mode/developer_mode.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('forms'); // open box with name "forms"
  await Hive.openBox('excavator_forms'); // open box with name "excavator_forms"
  await Hive.openBox('dozer_forms'); // open box with name "dozer_forms"
  await Hive.openBox('grader_forms'); // open box with name "grader_forms"
  await Hive.openBox('hd_forms'); // open box with name "hd_forms"
  await Hive.openBox('hdt_forms'); // open box with name "hdt_forms"
  await Hive.openBox('dt_forms'); // open box with name "dt_forms"
  await Hive.openBox('wl_forms'); // open box with name "dt_forms"
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;

  bool? _isJailbroken;
  bool? _isDeveloperMode;

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    setState(() {
      _isLoggedIn = accessToken != null && accessToken.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _checkUsernameAndRedirect();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final isJailbroken = await DeveloperMode.isJailbroken;
    final isDeveloperMode = await DeveloperMode.isDeveloperMode;

    setState(() {
      _isJailbroken = isJailbroken;
      _isDeveloperMode = isDeveloperMode;
    });
  }

  Future<void> _checkUsernameAndRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null || accessToken.isEmpty) {
      final myAppState = context.findAncestorStateOfType<_MyAppState>();
      if (myAppState != null) {
        myAppState.setState(() {
          myAppState._isLoggedIn = false;
        });
      }
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    print('\n🚪 _onLogout called in MyApp');
    setState(() {
      _isLoggedIn = false;
    });
    print('✅ Login status set to false in MyApp');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while security check is in progress
    if (_isJailbroken == null || _isDeveloperMode == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mobile Attendance App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Block app if device is jailbroken or in developer mode
    if (_isJailbroken == true || _isDeveloperMode == true) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mobile Attendance App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'App Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This app cannot run on jailbroken devices\nor devices with developer mode enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Optional: exit app
                  },
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _isLoggedIn
          ? MainScaffold(onLogout: _onLogout)
          : LoginPage(onLoginSuccess: _onLoginSuccess),
    );
  }
}

// DashboardPage removed; replaced by MainScaffold

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  final VoidCallback? onLogout;
  const MainScaffold({Key? key, this.initialIndex = 0, this.onLogout})
    : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _appMode = 0; // 0 = selection, 1 = attendance, 2 = inspection

  static const List<String> _titles = [
    'Select Application',
    'Home',
    'Menu',
    'Logout',
    'ADT List',
    'Excavator List',
    'Dozer List',
    'Grader List',
    'HD List',
    'HDT List',
    'DT List',
    'WL List',
  ];

  static void _navigateToSublist(BuildContext context, int sublistIndex) {
    final state = context.findAncestorStateOfType<_MainScaffoldState>();
    state?.setState(() {
      state._selectedIndex = sublistIndex;
      state._appMode = 2; // Switch to inspection mode
    });
  }

  void _handleAppSelection(BuildContext context, String appType) {
    setState(() {
      if (appType == 'attendance') {
        _appMode = 1; // Attendance mode
        _selectedIndex = 1; // Home page
      } else if (appType == 'inspection') {
        _appMode = 2; // Inspection mode
        _selectedIndex = 2; // Menu page
      }
    });
  }

  void _handleReturnToAppSelection() {
    setState(() {
      _appMode = 0;
      _selectedIndex = 0;
    });
  }

  void _handleAutoLogout() {
    print('\n🔄 _handleAutoLogout called from MainScaffold');

    try {
      // Call the logout callback passed from MyApp
      if (widget.onLogout != null) {
        print('✅ Calling onLogout callback from MyApp');
        widget.onLogout!();
        print('✅ Logout callback completed successfully');
      } else {
        print('❌ ERROR: onLogout callback is null!');
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION in _handleAutoLogout: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  List<Widget> get _pages => [
    AppSelectionPage(onNavigate: _handleAppSelection),
    HomePage(onLogout: _handleAutoLogout),
    MenuPage(onNavigate: _navigateToSublist),
    Center(child: Text('Logout')),
    ADTListPage(),
    ExcavatorListPage(),
    DozerListPage(),
    GraderListPage(),
    HDListPage(),
    HDTListPage(),
    DTListPage(),
    WLListPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Logout button pressed
      print('\n🚪 Logout button tapped in MainScaffold');
      
      try {
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
        await prefs.remove('username');
        print('✅ All local authentication data cleared');
        
        // 3. Call the logout callback to trigger state change in MyApp
        if (widget.onLogout != null) {
          print('🔄 Calling onLogout callback from _onItemTapped');
          widget.onLogout!();
          print('✅ Logout successful, returning to login page');
        } else {
          print('❌ ERROR: onLogout callback is null!');
        }
      } catch (e, stackTrace) {
        print('❌ ERROR in logout: $e');
        print('   Stack trace: $stackTrace');
      }
    } else if (index == 3) {
      // Back to app selection from attendance
      _handleReturnToAppSelection();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<String?> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  @override
  Widget build(BuildContext context) {
    // For app selection mode, show minimal UI
    if (_appMode == 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[0]),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan[300]!, Colors.green[300]!],
              ),
            ),
          ),
          actions: [
            FutureBuilder<String?>(
              future: _getUsername(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final username = snapshot.data ?? 'User';
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage(onLogout: _handleAutoLogout)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(username),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
          ],
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              _handleReturnToAppSelection(); // Home -> App Selection
            } else if (index == 1) {
              _onItemTapped(2); // Logout
            }
          },
        ),
      );
    }

    // For attendance and inspection modes
    int displayIndex = _selectedIndex;
    if (_appMode == 1 && _selectedIndex > 2) {
      displayIndex = 1; // Clamp to home for attendance mode
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan[300]!, Colors.green[300]!],
            ),
          ),
        ),
        leading: (_appMode == 1 && _selectedIndex == 1)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleReturnToAppSelection,
              )
            : (_selectedIndex > 3)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 2; // Go back to Menu
                      });
                    },
                  )
                : null,
        actions: [
          FutureBuilder<String?>(
            future: _getUsername(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final username = snapshot.data ?? 'User';
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage(onLogout: _handleAutoLogout)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 8),
                      Text(username),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _appMode == 1
          ? BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.arrow_back), label: 'Back'),
                BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
              ],
              currentIndex: _selectedIndex >= 1 && _selectedIndex <= 2 ? _selectedIndex - 1 : 0,
              onTap: (index) {
                if (index == 0) {
                  _handleReturnToAppSelection(); // Home -> App Selection
                } else if (index == 1) {
                  _handleReturnToAppSelection(); // Back
                } else if (index == 2) {
                  _onItemTapped(2); // Logout
                }
              },
            )
          : BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
                BottomNavigationBarItem(icon: Icon(Icons.arrow_back), label: 'Back'),
              ],
              currentIndex: _selectedIndex > 3 ? 1 : _selectedIndex == 2 ? 1 : 0,
              onTap: (index) {
                if (index == 0) {
                  _handleReturnToAppSelection(); // Home -> App Selection
                } else if (index == 1) {
                  setState(() {
                    _selectedIndex = 2; // Menu
                  });
                } else if (index == 2) {
                  _handleReturnToAppSelection(); // Back
                }
              },
            ),
    );
  }
}

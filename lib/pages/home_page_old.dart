import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  // Future<String?> _getUsername() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   return prefs.getString('username');
  // }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image(image: AssetImage('assets/images/gmt.png'))
    );
  }
}

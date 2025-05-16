import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/main_page.dart';
import 'screens/backoffice_page.dart';
import 'screens/server_down_page.dart';

void main() {
  runApp(const IrrigApp());
}

class IrrigApp extends StatelessWidget {
  const IrrigApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRRIGO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/main': (_) => const MainPage(),
        '/admin': (_) => const BackOfficePage(),
        '/down': (_) => const ServerDownPage(),
      },
    );
  }
}
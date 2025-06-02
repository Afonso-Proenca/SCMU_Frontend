import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:irrig_app/services/user_service.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/main_page.dart';
import 'screens/backoffice_page.dart';
import 'screens/server_down_page.dart';
import 'firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:provider/provider.dart';


import 'firebase/auth.dart';
import 'services/data_service.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 /* if (kDebugMode) {
    try {
      print("debug");
      //FirebaseAuth.instance.useAuthEmulator('172.20.10.5', 9099);
      //FirebaseDatabase.instance.useDatabaseEmulator('172.20.10.5', 9001);


    } catch (e) {
      print(e);
    }
  }*/
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DataService>(create: (_) => DataService()),
        Provider<UserService>(create: (_) => UserService()),
      ],
      child: const IrrigApp(),
    ),
  );
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